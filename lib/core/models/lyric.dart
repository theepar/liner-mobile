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

/// How precisely a lyrics source is timed.
enum LyricsSyncLevel {
  syllable(3, 'Syllable synced'),
  word(2, 'Word synced'),
  line(1, 'Line synced'),
  plain(0, 'Not synced');

  const LyricsSyncLevel(this.rank, this.label);

  final int rank;
  final String label;

  static LyricsSyncLevel parse(String? value) => switch (value) {
    'syllable_level' => syllable,
    'word_level' => word,
    'line_level' => line,
    _ => plain,
  };
}

/// One provider's lyrics as streamed by `GET /v1/tracks/:id/lyrics`.
class LyricsCandidate {
  const LyricsCandidate({
    required this.provider,
    required this.format,
    required this.content,
    required this.syncLevel,
    this.quality = 0,
  });

  /// Reads a `provider` event whose status is `found`.
  static LyricsCandidate? fromEvent(JsonMap event) {
    if (event['type'] != 'provider' || event['status'] != 'found') return null;
    final candidate = asMap(event['candidate']);
    final lyrics = asMap(candidate?['lyrics']);
    final content = asString(lyrics?['content']);
    final provider =
        asString(candidate?['provider']) ?? asString(event['provider']);
    if (candidate == null ||
        content == null ||
        content.trim().isEmpty ||
        provider == null) {
      return null;
    }
    final quality = asMap(candidate['quality'])?['total'];
    return LyricsCandidate(
      provider: provider,
      format: asString(lyrics?['format']) ?? 'plain',
      content: content,
      syncLevel: LyricsSyncLevel.parse(
        asString(candidate['syncLevel']) ?? asString(event['syncLevel']),
      ),
      quality: quality is num ? quality : 0,
    );
  }

  final String provider;
  final String format;
  final String content;
  final LyricsSyncLevel syncLevel;
  final num quality;

  /// Better synced candidates first, then higher quality.
  static int compare(LyricsCandidate a, LyricsCandidate b) {
    final bySync = b.syncLevel.rank.compareTo(a.syncLevel.rank);
    return bySync != 0 ? bySync : b.quality.compareTo(a.quality);
  }
}

/// Parsed lyrics: time-synced lines, or plain text when there is no timing.
class LyricsDocument {
  const LyricsDocument({this.lines = const [], this.plainText});

  final List<LyricLine> lines;
  final String? plainText;

  bool get isSynced => lines.isNotEmpty;
  bool get isEmpty => lines.isEmpty && (plainText?.trim().isEmpty ?? true);
}

/// A provider the user can switch to.
class LyricsOption {
  const LyricsOption({
    required this.provider,
    required this.syncLevel,
    required this.quality,
  });

  final String provider;
  final LyricsSyncLevel syncLevel;
  final num quality;
}
