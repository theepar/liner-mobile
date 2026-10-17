import '../core/models/playback_event.dart';
import '../core/models/track.dart';
import '../core/utils/uuid.dart';

class PlaybackTelemetry {
  PlaybackTelemetry({
    required this.onEvent,
    this._clock = DateTime.now,
    this._newId = newUuid,
  });

  static const minReportedMs = 3000;

  static const skipThresholdMs = 30000;

  static const sessionTimeout = Duration(minutes: 30);

  final void Function(PlaybackEvent event) onEvent;
  final DateTime Function() _clock;
  final String Function() _newId;

  String? _trackId;
  String _playbackSessionId = '';
  String? _listeningSessionId;
  DateTime? _lastActivity;
  DateTime? _playingSince;
  int _trackDurationMs = 0;
  int _playedMs = 0;
  bool _completed = false;
  int _loopCount = 0;
  bool _seekedBackward = false;
  PlaybackContext? _context;

  void startTrack(Track track, PlaybackContext? context) {
    flush();
    _trackId = track.id;
    _playbackSessionId = _newId();
    _trackDurationMs = track.durationMs;
    _context = context;

    final now = _clock();
    final last = _lastActivity;
    if (_listeningSessionId == null ||
        last == null ||
        now.difference(last) > sessionTimeout) {
      _listeningSessionId = _newId();
    }
    _lastActivity = now;
  }

  void onPlaying() {
    if (_trackId == null) return;
    final now = _clock();
    _playingSince ??= now;
    _lastActivity = now;
  }

  void onPausedOrStopped() {
    if (_trackId == null) return;
    _accumulate();
  }

  void onSeekBackward() {
    if (_trackId == null) return;
    _seekedBackward = true;
    _lastActivity = _clock();
  }

  void onCompleted({required bool repeatOne}) {
    if (_trackId == null) return;
    _accumulate();
    _completed = true;
    if (repeatOne) _loopCount += 1;
  }

  void flush() {
    final trackId = _trackId;
    if (trackId == null) return;
    _accumulate();

    if (_playedMs >= minReportedMs || _completed) {
      final basis = _trackDurationMs > 0 ? _trackDurationMs : _playedMs;
      final rawRate = basis > 0 ? _playedMs / basis : (_completed ? 1.0 : 0.0);
      onEvent(
        PlaybackEvent(
          playbackSessionId: _playbackSessionId,
          listeningSessionId: _listeningSessionId ?? _newId(),
          trackId: trackId,
          playedDurationMs: _playedMs,
          trackDurationMs: _trackDurationMs > 0 ? _trackDurationMs : null,
          completionRate: double.parse(
            rawRate.clamp(0.0, 1.0).toStringAsFixed(4),
          ),
          completed: _completed,
          skipped: !_completed && _playedMs < skipThresholdMs,
          loopCount: _loopCount,
          hasSeekBackward: _seekedBackward,
          context: _context,
        ),
      );
    }

    _trackId = null;
    _playbackSessionId = '';
    _playedMs = 0;
    _completed = false;
    _loopCount = 0;
    _seekedBackward = false;
    _context = null;
  }

  /// Counts only active playback so idle gaps rotate listening sessions.
  void _accumulate() {
    final since = _playingSince;
    if (since == null) return;
    final now = _clock();
    final delta = now.difference(since).inMilliseconds;
    if (delta > 0) _playedMs += delta;
    _playingSince = null;
    _lastActivity = now;
  }
}
