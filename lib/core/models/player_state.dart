import 'track.dart';

enum PlaybackStatus {
  initial,
  loading,
  playing,
  paused,
  completed,
  error,
}

enum LinerRepeatMode {
  off,
  all,
  one,
}

class PlayerStateData {
  final Track? currentTrack;
  final List<Track> queue;
  final int currentIndex;
  final PlaybackStatus status;
  final Duration position;
  final Duration duration;
  final bool isShuffle;
  final LinerRepeatMode repeatMode;
  final double playbackSpeed;
  final double pitch;
  final bool isLyricsOpen;
  final List<LyricLine> lyrics;
  final bool isLoadingLyrics;
  final Set<String> likedTrackIds;

  const PlayerStateData({
    this.currentTrack,
    this.queue = const [],
    this.currentIndex = 0,
    this.status = PlaybackStatus.initial,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isShuffle = false,
    this.repeatMode = LinerRepeatMode.off,
    this.playbackSpeed = 1.0,
    this.pitch = 1.0,
    this.isLyricsOpen = false,
    this.lyrics = const [],
    this.isLoadingLyrics = false,
    this.likedTrackIds = const {},
  });

  bool get isPlaying => status == PlaybackStatus.playing;
  bool get isBuffering => status == PlaybackStatus.loading;
  bool get hasTrack => currentTrack != null;
  bool get isCurrentLiked => currentTrack != null && likedTrackIds.contains(currentTrack!.id);

  double get progress {
    if (duration.inMilliseconds == 0) return 0.0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  PlayerStateData copyWith({
    Track? currentTrack,
    bool clearTrack = false,
    List<Track>? queue,
    int? currentIndex,
    PlaybackStatus? status,
    Duration? position,
    Duration? duration,
    bool? isShuffle,
    LinerRepeatMode? repeatMode,
    double? playbackSpeed,
    double? pitch,
    bool? isLyricsOpen,
    List<LyricLine>? lyrics,
    bool? isLoadingLyrics,
    Set<String>? likedTrackIds,
  }) =>
      PlayerStateData(
        currentTrack: clearTrack ? null : (currentTrack ?? this.currentTrack),
        queue: queue ?? this.queue,
        currentIndex: currentIndex ?? this.currentIndex,
        status: status ?? this.status,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        isShuffle: isShuffle ?? this.isShuffle,
        repeatMode: repeatMode ?? this.repeatMode,
        playbackSpeed: playbackSpeed ?? this.playbackSpeed,
        pitch: pitch ?? this.pitch,
        isLyricsOpen: isLyricsOpen ?? this.isLyricsOpen,
        lyrics: lyrics ?? this.lyrics,
        isLoadingLyrics: isLoadingLyrics ?? this.isLoadingLyrics,
        likedTrackIds: likedTrackIds ?? this.likedTrackIds,
      );
}
