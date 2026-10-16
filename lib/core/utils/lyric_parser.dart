import 'dart:convert';
import '../models/track.dart';

class LyricParser {
  static List<LyricLine> parse(String raw, {int songDurationMs = 0}) {
    if (raw.trim().isEmpty) return [];

    final trimmed = raw.trim();

    if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
      final jsonLines = _tryParseJson(trimmed);
      if (jsonLines != null && jsonLines.isNotEmpty) {
        return jsonLines;
      }
    }

    final lrcLines = _tryParseLrc(trimmed, songDurationMs);
    if (lrcLines.isNotEmpty) {
      return lrcLines;
    }

    return _parsePlainText(trimmed, songDurationMs);
  }

  static List<LyricLine>? _tryParseJson(String raw) {
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is List) {
        if (decoded.isNotEmpty && decoded.first is Map && (decoded.first['ts'] != null || decoded.first['time'] != null)) {
          final List<LyricLine> result = [];
          for (int i = 0; i < decoded.length; i++) {
            final item = decoded[i] as Map<String, dynamic>;
            final double ts = (item['ts'] as num?)?.toDouble() ??
                ((item['time'] is Map ? item['time']['total'] : item['time']) as num?)?.toDouble() ??
                0.0;
            final double te = (item['te'] as num?)?.toDouble() ?? ts + 3.0;

            final int startMs = (ts * 1000).round();
            final int endMs = (te * 1000).round();

            final List<LyricWord> words = [];
            if (item['l'] is List) {
              final wordsArray = item['l'] as List<dynamic>;
              for (int wIdx = 0; wIdx < wordsArray.length; wIdx++) {
                final w = wordsArray[wIdx];
                if (w is Map<String, dynamic>) {
                  final String wordText = w['c']?.toString() ?? '';
                  final double rawOffset = (w['o'] as num?)?.toDouble() ?? ts;
                  final int wordStartMs = rawOffset >= ts ? (rawOffset * 1000).round() : startMs + (rawOffset * 1000).round();

                  int wordEndMs = endMs;
                  if (wIdx + 1 < wordsArray.length && wordsArray[wIdx + 1] is Map) {
                    final nextOffset = (wordsArray[wIdx + 1]['o'] as num?)?.toDouble();
                    if (nextOffset != null) {
                      wordEndMs = nextOffset >= ts ? (nextOffset * 1000).round() : startMs + (nextOffset * 1000).round();
                    }
                  }

                  words.add(LyricWord(
                    startMs: wordStartMs,
                    endMs: wordEndMs,
                    text: wordText,
                  ));
                }
              }
            }

            final String lineText = item['text']?.toString() ??
                (words.isNotEmpty ? words.map((w) => w.text).join('') : '');

            result.add(LyricLine(
              startMs: startMs,
              endMs: endMs,
              text: lineText.trim(),
              words: words,
            ));
          }
          return result;
        }
      }
    } catch (_) {}
    return null;
  }

  static List<LyricLine> _tryParseLrc(String raw, int songDurationMs) {
    final List<LyricLine> result = [];
    final lines = raw.split('\n');
    final timeTagRegExp = RegExp(r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]');
    final wordTagRegExp = RegExp(r'<(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?>([^<]+)');

    for (final line in lines) {
      final match = timeTagRegExp.firstMatch(line);
      if (match != null) {
        final min = int.parse(match.group(1)!);
        final sec = int.parse(match.group(2)!);
        final frac = match.group(3) != null ? int.parse(match.group(3)!.padRight(3, '0')) : 0;
        final startMs = (min * 60 + sec) * 1000 + frac;

        final rawText = line.substring(match.end).trim();
        final wordMatches = wordTagRegExp.allMatches(rawText);
        final List<LyricWord> words = [];

        if (wordMatches.isNotEmpty) {
          for (final wm in wordMatches) {
            final wMin = int.parse(wm.group(1)!);
            final wSec = int.parse(wm.group(2)!);
            final wFrac = wm.group(3) != null ? int.parse(wm.group(3)!.padRight(3, '0')) : 0;
            final wStart = (wMin * 60 + wSec) * 1000 + wFrac;
            final wText = wm.group(4) ?? '';
            words.add(LyricWord(
              startMs: wStart,
              endMs: wStart + 500,
              text: wText,
            ));
          }
          for (int i = 0; i < words.length - 1; i++) {
            words[i] = LyricWord(
              startMs: words[i].startMs,
              endMs: words[i + 1].startMs,
              text: words[i].text,
            );
          }
        }

        final cleanText = rawText.replaceAll(RegExp(r'<[^>]+>'), '').trim();

        result.add(LyricLine(
          startMs: startMs,
          endMs: startMs + 4000,
          text: cleanText,
          words: words,
        ));
      }
    }

    for (int i = 0; i < result.length; i++) {
      final nextStart = (i + 1 < result.length)
          ? result[i + 1].startMs
          : (songDurationMs > result[i].startMs ? songDurationMs : result[i].startMs + 4000);
      result[i] = LyricLine(
        startMs: result[i].startMs,
        endMs: nextStart,
        text: result[i].text,
        words: result[i].words,
      );
    }

    return result;
  }

  static List<LyricLine> _parsePlainText(String raw, int songDurationMs) {
    final lines = raw.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return [];

    final stepMs = songDurationMs > 0 ? (songDurationMs / lines.length).round() : 3500;
    return List.generate(lines.length, (index) {
      final start = index * stepMs;
      return LyricLine(
        startMs: start,
        endMs: start + stepMs,
        text: lines[index].trim(),
      );
    });
  }

  static int findActiveLineIndex(List<LyricLine> lines, int currentMs) {
    if (lines.isEmpty) return -1;
    if (currentMs < lines.first.startMs) return 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (currentMs >= line.startMs && currentMs < line.endMs) {
        return i;
      }
    }

    if (currentMs >= lines.last.startMs) {
      return lines.length - 1;
    }

    return 0;
  }

  static double getWordProgress(LyricWord word, int currentMs) {
    if (currentMs <= word.startMs) return 0.0;
    if (currentMs >= word.endMs) return 1.0;
    final total = word.endMs - word.startMs;
    if (total <= 0) return 1.0;
    return ((currentMs - word.startMs) / total).clamp(0.0, 1.0);
  }

  static List<GroupedWord> groupSyllablesIntoWords(List<LyricWord> rawWords, String lineText) {
    if (rawWords.isEmpty) return const [];
    final List<GroupedWord> words = [];
    List<LyricWord> currentGroup = [];
    int charCursor = 0;

    for (int i = 0; i < rawWords.length; i++) {
      final w = rawWords[i];
      final trimmed = w.text.trim();
      if (trimmed.isEmpty) {
        if (currentGroup.isNotEmpty) {
          words.add(_createGroupedWord(currentGroup));
          currentGroup = [];
        }
        continue;
      }

      final foundIdx = lineText.isNotEmpty ? lineText.indexOf(trimmed, charCursor) : -1;
      bool isContinuation = false;

      if (currentGroup.isNotEmpty) {
        final prevSyllable = currentGroup.last;
        final prevEndsSpace = prevSyllable.text.endsWith(' ');
        final currStartsSpace = w.text.startsWith(' ');

        if (foundIdx >= 0) {
          final textBetween = lineText.substring(charCursor, foundIdx);
          final hasSpaceBetween = RegExp(r'\s').hasMatch(textBetween);
          if (!hasSpaceBetween && !prevEndsSpace && !currStartsSpace) {
            isContinuation = true;
          }
        } else if (!prevEndsSpace && !currStartsSpace) {
          isContinuation = true;
        }
      }

      if (foundIdx >= 0) {
        charCursor = foundIdx + trimmed.length;
      }

      if (isContinuation) {
        currentGroup.add(w);
      } else {
        if (currentGroup.isNotEmpty) {
          words.add(_createGroupedWord(currentGroup));
        }
        currentGroup = [w];
      }
    }

    if (currentGroup.isNotEmpty) {
      words.add(_createGroupedWord(currentGroup));
    }

    return words;
  }

  static GroupedWord _createGroupedWord(List<LyricWord> syllables) {
    return GroupedWord(
      syllables: List.unmodifiable(syllables),
      text: syllables.map((s) => s.text).join(),
      startMs: syllables.first.startMs,
      endMs: syllables.last.endMs,
    );
  }
}
