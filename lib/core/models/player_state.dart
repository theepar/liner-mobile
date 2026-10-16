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
    this.lyricsOptions = const [],
    this.activeLyricsProvider,
    this.lyricsOffsetMs = 0,
    this.lyricsPlainText,
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
  final List<LyricsOption> lyricsOptions;
  final String? activeLyricsProvider;
  final int lyricsOffsetMs;

  /// Set instead of [lyrics] when the active provider has no timing.
  final String? lyricsPlainText;
  final bool isLoadingLyrics;

  bool get isPlaying => status == PlaybackStatus.playing;
  bool get isBuffering => status == PlaybackStatus.loading;
  bool get hasError => status == PlaybackStatus.error;
  bool get hasLyrics =>
      lyrics.isNotEmpty || (lyricsPlainText?.isNotEmpty ?? false);

  double get progress {
    if (duration.inMilliseconds == 0) return 0.0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Replaces every lyrics field at once, so a provider without plain text
  /// (or without a selection) clears what the previous one left behind.
  PlayerStateData withLyrics({
    required List<LyricLine> lines,
    required List<LyricsOption> options,
    required String? activeProvider,
    required int offsetMs,
    required String? plainText,
    bool? isLoading,
  }) => PlayerStateData(
    currentTrack: currentTrack,
    queue: queue,
    currentIndex: currentIndex,
    status: status,
    position: position,
    duration: duration,
    isShuffle: isShuffle,
    repeatMode: repeatMode,
    playbackSpeed: playbackSpeed,
    pitch: pitch,
    isLyricsOpen: isLyricsOpen,
    lyrics: lines,
    lyricsOptions: options,
    activeLyricsProvider: activeProvider,
    lyricsOffsetMs: offsetMs,
    lyricsPlainText: plainText,
    isLoadingLyrics: isLoading ?? isLoadingLyrics,
  );

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
    List<LyricsOption>? lyricsOptions,
    String? activeLyricsProvider,
    int? lyricsOffsetMs,
    String? lyricsPlainText,
    bool clearLyrics = false,
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
    lyrics: clearLyrics ? const [] : (lyrics ?? this.lyrics),
    lyricsOptions: clearLyrics
        ? const []
        : (lyricsOptions ?? this.lyricsOptions),
    activeLyricsProvider: clearLyrics
        ? null
        : (activeLyricsProvider ?? this.activeLyricsProvider),
    lyricsOffsetMs: clearLyrics ? 0 : (lyricsOffsetMs ?? this.lyricsOffsetMs),
    lyricsPlainText: clearLyrics
        ? null
        : (lyricsPlainText ?? this.lyricsPlainText),
    isLoadingLyrics: isLoadingLyrics ?? this.isLoadingLyrics,
  );
}
