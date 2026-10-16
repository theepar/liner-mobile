import 'dart:convert';

import 'package:xml/xml.dart';

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

  /// Parses one provider's lyrics according to its declared format. Synced
  /// formats that yield no timed lines produce an empty document rather than
  /// text with invented timing.
  static LyricsDocument parseCandidate(
    LyricsCandidate candidate, {
    int songDurationMs = 0,
  }) {
    final content = candidate.content;
    final lines = switch (candidate.format) {
      'plain' => const <LyricLine>[],
      'ttml' => parseTtml(content),
      'qrc' => parseQrc(content),
      'lrc' || 'richsync' => parse(content, songDurationMs: songDurationMs),
      _ => parse(content, songDurationMs: songDurationMs),
    };
    if (lines.isNotEmpty) return LyricsDocument(lines: lines);
    if (candidate.format == 'plain' ||
        candidate.syncLevel == LyricsSyncLevel.plain) {
      return LyricsDocument(plainText: content.trim());
    }
    return const LyricsDocument();
  }

  /// Moves every line and word by [offsetMs]; positive values show the lyrics
  /// later.
  static List<LyricLine> shift(List<LyricLine> lines, int offsetMs) {
    if (offsetMs == 0) return lines;
    int move(int value) => value + offsetMs < 0 ? 0 : value + offsetMs;
    return [
      for (final line in lines)
        LyricLine(
          startMs: move(line.startMs),
          endMs: move(line.endMs),
          text: line.text,
          isInstrumental: line.isInstrumental,
          words: [
            for (final word in line.words)
              LyricWord(
                startMs: move(word.startMs),
                endMs: move(word.endMs),
                text: word.text,
              ),
          ],
        ),
    ];
  }

  /// Timed-text (TTML) lyrics: line paragraphs with optional timed spans for
  /// words or syllables.
  static List<LyricLine> parseTtml(String raw) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(raw);
    } on XmlException {
      return const [];
    }

    final lines = <LyricLine>[];
    for (final paragraph in document.findAllElements('p', namespace: '*')) {
      final start = _ttmlTime(paragraph.getAttribute('begin'));
      if (start == null) continue;

      final words = <LyricWord>[];
      _collectTtmlWords(paragraph, words);
      final text = words.isEmpty
          ? _collapseWhitespace(paragraph.innerText)
          : words.map((word) => word.text).join().trim();
      if (text.isEmpty) continue;

      var end = _ttmlTime(paragraph.getAttribute('end'));
      final duration = _ttmlTime(paragraph.getAttribute('dur'));
      end ??= duration == null ? null : start + duration;
      end ??= words.isEmpty ? start + 4000 : words.last.endMs;
      lines.add(
        LyricLine(startMs: start, endMs: end, text: text, words: words),
      );
    }
    return lines;
  }

  static void _collectTtmlWords(XmlNode node, List<LyricWord> words) {
    for (final child in node.children) {
      if (child is XmlText) {
        if (child.value.trim().isEmpty && words.isNotEmpty) {
          final last = words.last;
          if (!last.text.endsWith(' ')) {
            words[words.length - 1] = LyricWord(
              startMs: last.startMs,
              endMs: last.endMs,
              text: '${last.text} ',
            );
          }
        }
      } else if (child is XmlElement && child.localName == 'span') {
        final role = child.attributes
            .where((attribute) => attribute.name.local == 'role')
            .map((attribute) => attribute.value)
            .firstOrNull;
        if (role == 'x-translation' || role == 'x-roman') continue;

        final start = _ttmlTime(child.getAttribute('begin'));
        final end = _ttmlTime(child.getAttribute('end'));
        final hasTimedChildren = child.descendantElements.any(
          (element) => element.getAttribute('begin') != null,
        );
        if (hasTimedChildren) {
          _collectTtmlWords(child, words);
        } else if (start != null && end != null && child.innerText.isNotEmpty) {
          words.add(
            LyricWord(startMs: start, endMs: end, text: child.innerText),
          );
        }
      }
    }
  }

  static final _clockTime = RegExp(
    r'^(?:(\d+):)?(\d{1,2}):(\d{1,2})(?:[.,](\d+))?$',
  );
  static final _offsetTime = RegExp(r'^(\d+(?:\.\d+)?)(h|ms|m|s)?$');

  static int? _ttmlTime(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;

    final clock = _clockTime.firstMatch(text);
    if (clock != null) {
      final hours = int.parse(clock.group(1) ?? '0');
      final minutes = int.parse(clock.group(2)!);
      final seconds = int.parse(clock.group(3)!);
      final fraction = clock.group(4);
      final millis = fraction == null
          ? 0
          : int.parse(fraction.padRight(3, '0').substring(0, 3));
      return ((hours * 60 + minutes) * 60 + seconds) * 1000 + millis;
    }

    final offset = _offsetTime.firstMatch(text);
    if (offset == null) return null;
    final amount = double.parse(offset.group(1)!);
    return switch (offset.group(2)) {
      'h' => (amount * 3600000).round(),
      'm' => (amount * 60000).round(),
      'ms' => amount.round(),
      _ => (amount * 1000).round(),
    };
  }

  static String _collapseWhitespace(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// QRC lyrics: `[lineStartMs,lineDurationMs]word(startMs,durationMs)...`.
  static List<LyricLine> parseQrc(String raw) {
    var text = raw;
    final wrapped = RegExp(r'LyricContent="([^"]*)"').firstMatch(raw);
    if (wrapped != null) {
      text = const XmlDefaultEntityMapping.xml().decode(wrapped.group(1)!);
    }

    final linePattern = RegExp(r'^\[(\d+),(\d+)\](.*)$');
    final wordPattern = RegExp(r'([^()]*?)\((\d+),(\d+)\)');
    final lines = <LyricLine>[];
    for (final rawLine in text.split(RegExp(r'\r?\n'))) {
      final match = linePattern.firstMatch(rawLine.trim());
      if (match == null) continue;
      final start = int.parse(match.group(1)!);
      final duration = int.parse(match.group(2)!);
      final body = match.group(3)!;

      final words = [
        for (final word in wordPattern.allMatches(body))
          if (word.group(1)!.isNotEmpty)
            LyricWord(
              startMs: int.parse(word.group(2)!),
              endMs: int.parse(word.group(2)!) + int.parse(word.group(3)!),
              text: word.group(1)!,
            ),
      ];
      final lineText = words.isEmpty
          ? body.trim()
          : words.map((word) => word.text).join().trim();
      if (lineText.isEmpty) continue;
      lines.add(
        LyricLine(
          startMs: start,
          endMs: start + duration,
          text: lineText,
          words: words,
        ),
      );
    }
    return lines;
  }

  static int findActiveLineIndex(List<LyricLine> lines, int currentMs) {
    if (lines.isEmpty) return -1;
    for (var i = lines.length - 1; i >= 0; i--) {
      if (currentMs >= lines[i].startMs) return i;
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
