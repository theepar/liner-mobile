import 'package:just_audio/just_audio.dart' as just_audio;

abstract interface class AudioEngine {
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<EngineState> get stateStream;
  bool get isPlaying;

  Future<void> setUrl(String url);

  /// Completes only after playback stops; callers must not await it.
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> setPitch(double pitch);
  Future<void> dispose();
}

enum EngineProcessing { idle, loading, buffering, ready, completed }

class EngineState {
  const EngineState({required this.isPlaying, required this.processing});

  final bool isPlaying;
  final EngineProcessing processing;
}

class JustAudioEngine implements AudioEngine {
  JustAudioEngine([just_audio.AudioPlayer? player])
    : _player = player ?? just_audio.AudioPlayer();

  final just_audio.AudioPlayer _player;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<EngineState> get stateStream => _player.playerStateStream.map(
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
  bool get isPlaying => _player.playing;

  @override
  Future<void> setUrl(String url) => _player.setUrl(url);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> setPitch(double pitch) => _player.setPitch(pitch);

  @override
  Future<void> dispose() => _player.dispose();
}
