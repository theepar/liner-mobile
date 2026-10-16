import 'lyric.dart';
import 'track.dart';

enum PlaybackStatus { initial, loading, playing, paused, completed, error }

enum LinerRepeatMode { off, all, one }

class PlayerStateData {
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
  });

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

  bool get isPlaying => status == PlaybackStatus.playing;
  bool get isBuffering => status == PlaybackStatus.loading;
  bool get hasError => status == PlaybackStatus.error;

  double get progress {
    if (duration.inMilliseconds == 0) return 0.0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  PlayerStateData copyWith({
    Track? currentTrack,
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
  }) => PlayerStateData(
    currentTrack: currentTrack ?? this.currentTrack,
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
  );
}
