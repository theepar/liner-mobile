import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart' as just_audio;

import '../core/models/track.dart';
import 'audio_cache.dart';
import 'audio_engine.dart';

class BackgroundAudioEngine implements AudioEngine {
  BackgroundAudioEngine._(this._handler, this._cache);

  final _LinerAudioHandler _handler;
  final AudioCache _cache;

  static Future<BackgroundAudioEngine> create() async {
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.music());
    final handler = await AudioService.init(
      builder: _LinerAudioHandler.new,
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.tryliner.liner_mobile.playback',
        androidNotificationChannelName: 'Liner playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: false,
      ),
    );
    return BackgroundAudioEngine._(handler, const AudioCache());
  }

  void bindQueueControls({
    required Future<void> Function() onNext,
    required Future<void> Function() onPrevious,
  }) {
    _handler
      ..onNext = onNext
      ..onPrevious = onPrevious;
  }

  void updateTrack(Track track) {
    _handler.mediaItem.add(
      MediaItem(
        id: track.id,
        title: track.title,
        artist: track.artistName,
        album: track.albumName,
        duration: Duration(milliseconds: track.durationMs),
        artUri: track.coverUrl.isEmpty ? null : Uri.tryParse(track.coverUrl),
      ),
    );
  }

  void updateQueue(List<Track> tracks, int index) {
    _handler.queue.add(
      tracks
          .map(
            (track) => MediaItem(
              id: track.id,
              title: track.title,
              artist: track.artistName,
              album: track.albumName,
              duration: Duration(milliseconds: track.durationMs),
              artUri: track.coverUrl.isEmpty
                  ? null
                  : Uri.tryParse(track.coverUrl),
            ),
          )
          .toList(growable: false),
    );
    _handler.queueIndex = index;
  }

  @override
  Stream<Duration> get positionStream => _handler.player.positionStream;

  @override
  Stream<Duration?> get durationStream => _handler.player.durationStream;

  @override
  Stream<EngineState> get stateStream => _handler.player.playerStateStream.map(
    (state) => EngineState(
      isPlaying: state.playing,
      processing: switch (state.processingState) {
        just_audio.ProcessingState.idle => EngineProcessing.idle,
        just_audio.ProcessingState.loading => EngineProcessing.loading,
        just_audio.ProcessingState.buffering => EngineProcessing.buffering,
        just_audio.ProcessingState.ready => EngineProcessing.ready,
        just_audio.ProcessingState.completed => EngineProcessing.completed,
      },
    ),
  );

  @override
  bool get isPlaying => _handler.player.playing;

  @override
  Future<void> setUrl(String url) async {
    await _handler.player.setAudioSource(
      // just_audio's streaming cache is the only API that caches while playing.
      // ignore: experimental_member_use
      just_audio.LockCachingAudioSource(
        Uri.parse(url),
        cacheFile: await _cache.fileForUrl(url),
      ),
    );
  }

  @override
  Future<void> play() => _handler.player.play();

  @override
  Future<void> pause() => _handler.player.pause();

  @override
  Future<void> stop() => _handler.player.stop();

  @override
  Future<void> seek(Duration position) => _handler.player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _handler.player.setSpeed(speed);

  @override
  Future<void> setPitch(double pitch) => _handler.player.setPitch(pitch);

  @override
  Future<void> dispose() => _handler.player.dispose();
}

class _LinerAudioHandler extends BaseAudioHandler with SeekHandler {
  final player = just_audio.AudioPlayer();
  Future<void> Function()? onNext;
  Future<void> Function()? onPrevious;
  int? queueIndex;

  _LinerAudioHandler() {
    player.playbackEventStream.listen(_broadcastState);
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> stop() => player.stop();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToNext() async {
    final callback = onNext;
    if (callback != null) await callback();
  }

  @override
  Future<void> skipToPrevious() async {
    final callback = onPrevious;
    if (callback != null) await callback();
  }

  void _broadcastState(just_audio.PlaybackEvent event) {
    final playing = player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: switch (player.processingState) {
          just_audio.ProcessingState.idle => AudioProcessingState.idle,
          just_audio.ProcessingState.loading => AudioProcessingState.loading,
          just_audio.ProcessingState.buffering =>
            AudioProcessingState.buffering,
          just_audio.ProcessingState.ready => AudioProcessingState.ready,
          just_audio.ProcessingState.completed =>
            AudioProcessingState.completed,
        },
        playing: playing,
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
        queueIndex: queueIndex,
      ),
    );
  }
}
