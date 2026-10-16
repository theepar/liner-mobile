import 'json_helpers.dart';

/// Where playback was started from, reported to the API for recommendations.
class PlaybackContext {
  const PlaybackContext(this.type, [this.id]);

  const PlaybackContext.playlist(String id) : this('playlist', id);

  static const explore = PlaybackContext('explore');
  static const search = PlaybackContext('search');
  static const library = PlaybackContext('library');

  final String type;
  final String? id;

  JsonMap toJson() => {'type': type, 'id': ?id};
}

/// Body of `POST /v1/me/playback/events`.
class PlaybackEvent {
  const PlaybackEvent({
    required this.playbackSessionId,
    required this.listeningSessionId,
    required this.trackId,
    required this.playedDurationMs,
    required this.completionRate,
    required this.completed,
    required this.skipped,
    required this.loopCount,
    required this.hasSeekBackward,
    this.trackDurationMs,
    this.context,
  });

  final String playbackSessionId;
  final String listeningSessionId;
  final String trackId;
  final int playedDurationMs;
  final int? trackDurationMs;
  final double completionRate;
  final bool completed;
  final bool skipped;
  final int loopCount;
  final bool hasSeekBackward;
  final PlaybackContext? context;

  JsonMap toJson() => {
    'playbackSessionId': playbackSessionId,
    'listeningSessionId': listeningSessionId,
    'trackId': trackId,
    'playedDurationMs': playedDurationMs,
    'trackDurationMs': ?trackDurationMs,
    'completionRate': completionRate,
    'completed': completed,
    'skipped': skipped,
    'loopCount': loopCount,
    'hasSeekBackward': hasSeekBackward,
    'context': ?context?.toJson(),
  };
}
