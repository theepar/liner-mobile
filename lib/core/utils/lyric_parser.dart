import 'dart:convert';

import '../models/json_helpers.dart';
import '../models/lyric.dart';

class LyricParser {
  /// Parses time-synced lyrics: Richsync JSON or LRC (optionally with
  /// word-level `<mm:ss.xx>` tags). Text without timing yields no lines.
  static List<LyricLine> parse(String raw, {int songDurationMs = 0}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return [];

    if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
      final jsonLines = _tryParseJson(trimmed);
      if (jsonLines != null && jsonLines.isNotEmpty) return jsonLines;
    }

    return _tryParseLrc(trimmed, songDurationMs);
  }

  static List<LyricLine>? _tryParseJson(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }

    final entries = asList(decoded);
    final first = entries == null || entries.isEmpty
        ? null
        : asMap(entries.first);
    if (entries == null ||
        first == null ||
        (first['ts'] == null && first['time'] == null)) {
      return null;
    }

    return [
      for (final entry in entries)
        if (asMap(entry) case final item?) _parseTimedLine(item),
    ];
  }

  static LyricLine _parseTimedLine(JsonMap item) {
    final time = item['time'];
    final ts =
        _seconds(item['ts']) ?? _seconds(asMap(time)?['total'] ?? time) ?? 0.0;
    final te = _seconds(item['te']) ?? ts + 3.0;
    final startMs = (ts * 1000).round();
    final endMs = (te * 1000).round();

    int toMs(double offset) => offset >= ts
        ? (offset * 1000).round()
        : startMs + (offset * 1000).round();

    final rawWords = asList(item['l']) ?? const <Object?>[];
    final words = <LyricWord>[];
    for (var i = 0; i < rawWords.length; i++) {
      final word = asMap(rawWords[i]);
      if (word == null) continue;

      final nextOffset = i + 1 < rawWords.length
          ? _seconds(asMap(rawWords[i + 1])?['o'])
          : null;
      words.add(
        LyricWord(
          startMs: toMs(_seconds(word['o']) ?? ts),
          endMs: nextOffset == null ? endMs : toMs(nextOffset),
          text: word['c']?.toString() ?? '',
        ),
      );
    }

    final text =
        item['text']?.toString() ?? words.map((word) => word.text).join();
    return LyricLine(
      startMs: startMs,
      endMs: endMs,
      text: text.trim(),
      words: words,
    );
  }

  static double? _seconds(Object? value) =>
      value is num ? value.toDouble() : null;

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
        final frac = match.group(3) != null
            ? int.parse(match.group(3)!.padRight(3, '0'))
            : 0;
        final startMs = (min * 60 + sec) * 1000 + frac;

        final rawText = line.substring(match.end).trim();
        final wordMatches = wordTagRegExp.allMatches(rawText);
        final List<LyricWord> words = [];

        if (wordMatches.isNotEmpty) {
          for (final wm in wordMatches) {
            final wMin = int.parse(wm.group(1)!);
            final wSec = int.parse(wm.group(2)!);
            final wFrac = wm.group(3) != null
                ? int.parse(wm.group(3)!.padRight(3, '0'))
                : 0;
            final wStart = (wMin * 60 + wSec) * 1000 + wFrac;
            final wText = wm.group(4) ?? '';
            words.add(
              LyricWord(startMs: wStart, endMs: wStart + 500, text: wText),
            );
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

        result.add(
          LyricLine(
            startMs: startMs,
            endMs: startMs + 4000,
            text: cleanText,
            words: words,
          ),
        );
      }
    }

    for (int i = 0; i < result.length; i++) {
      final nextStart = (i + 1 < result.length)
          ? result[i + 1].startMs
          : (songDurationMs > result[i].startMs
                ? songDurationMs
                : result[i].startMs + 4000);
      result[i] = LyricLine(
        startMs: result[i].startMs,
        endMs: nextStart,
        text: result[i].text,
        words: result[i].words,
      );
    }

    return result;
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

  static List<GroupedWord> groupSyllablesIntoWords(
    List<LyricWord> rawWords,
    String lineText,
  ) {
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

      final foundIdx = lineText.isNotEmpty
          ? lineText.indexOf(trimmed, charCursor)
          : -1;
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
