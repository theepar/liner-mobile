import 'json_helpers.dart';

class LyricLine {
  const LyricLine({
    required this.startMs,
    required this.endMs,
    required this.text,
    this.words = const [],
    this.isInstrumental = false,
  });

  factory LyricLine.fromJson(JsonMap json) => LyricLine(
    startMs: asInt(json['start_ms']) ?? asInt(json['timeMs']) ?? 0,
    endMs: asInt(json['end_ms']) ?? 0,
    text: asString(json['text']) ?? '',
    words: parseList(json['words'], LyricWord.fromJson),
    isInstrumental: asBool(json['isInstrumental']) ?? false,
  );

  final int startMs;
  final int endMs;
  final String text;
  final List<LyricWord> words;
  final bool isInstrumental;
}

class LyricWord {
  const LyricWord({
    required this.startMs,
    required this.endMs,
    required this.text,
  });

  factory LyricWord.fromJson(JsonMap json) => LyricWord(
    startMs: asInt(json['start_ms']) ?? asInt(json['timeMs']) ?? 0,
    endMs: asInt(json['end_ms']) ?? asInt(json['endMs']) ?? 0,
    text: asString(json['text']) ?? '',
  );

  final int startMs;
  final int endMs;
  final String text;
}

/// Consecutive syllables that belong to a single spoken word.
class GroupedWord {
  const GroupedWord({
    required this.syllables,
    required this.text,
    required this.startMs,
    required this.endMs,
  });

  final List<LyricWord> syllables;
  final String text;
  final int startMs;
  final int endMs;
}
