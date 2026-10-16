import '../core/models/lyric.dart';
import '../core/utils/lyric_parser.dart';

/// The lyrics available for one track: every provider that answered, which
/// one is shown, and the user's timing offset.
///
/// Providers arrive over time. Until the user picks one, the best candidate
/// seen so far is shown, so a better late arrival replaces a weaker early one.
class LyricsSession {
  LyricsSession({required this.durationMs, int offsetMs = 0})
    : _offsetMs = offsetMs.clamp(-maxOffsetMs, maxOffsetMs);

  static const maxOffsetMs = 60000;

  final int durationMs;
  final _entries = <_Entry>[];
  String? _active;
  bool _userChose = false;
  int _offsetMs;

  List<LyricsOption> get options => [
    for (final entry in _entries)
      LyricsOption(
        provider: entry.candidate.provider,
        syncLevel: entry.candidate.syncLevel,
        quality: entry.candidate.quality,
      ),
  ];

  String? get activeProvider => _active;
  int get offsetMs => _offsetMs;
  bool get hasLyrics => _active != null;

  _Entry? get _activeEntry {
    for (final entry in _entries) {
      if (entry.candidate.provider == _active) return entry;
    }
    return null;
  }

  /// Lines of the active provider with the offset applied.
  List<LyricLine> get lines =>
      LyricParser.shift(_activeEntry?.document.lines ?? const [], _offsetMs);

  String? get plainText => _activeEntry?.document.plainText;

  /// Adds a provider's lyrics. Returns false when they were unusable or the
  /// provider was already added.
  bool add(LyricsCandidate candidate) {
    if (_entries.any((e) => e.candidate.provider == candidate.provider)) {
      return false;
    }
    final document = LyricParser.parseCandidate(
      candidate,
      songDurationMs: durationMs,
    );
    if (document.isEmpty) return false;

    _entries
      ..add(_Entry(candidate, document))
      ..sort((a, b) => LyricsCandidate.compare(a.candidate, b.candidate));
    if (!_userChose) _active = _entries.first.candidate.provider;
    return true;
  }

  /// Switches to [provider]; false if it is unknown.
  bool select(String provider) {
    if (!_entries.any((e) => e.candidate.provider == provider)) return false;
    _userChose = true;
    _active = provider;
    return true;
  }

  void setOffset(int offsetMs) {
    _offsetMs = offsetMs.clamp(-maxOffsetMs, maxOffsetMs);
  }
}

class _Entry {
  const _Entry(this.candidate, this.document);

  final LyricsCandidate candidate;
  final LyricsDocument document;
}
