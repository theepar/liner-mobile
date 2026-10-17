import 'dart:async';

import 'package:liner_mobile/services/audio_engine.dart';

class FakeAudioEngine implements AudioEngine {
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration?>.broadcast();
  final _state = StreamController<EngineState>.broadcast();

  final calls = <String>[];
  String? loadedUrl;
  Object? setUrlError;
  bool _isPlaying = false;

  @override
  Stream<Duration> get positionStream => _position.stream;

  @override
  Stream<Duration?> get durationStream => _duration.stream;

  @override
  Stream<EngineState> get stateStream => _state.stream;

  @override
  bool get isPlaying => _isPlaying;

  @override
  Future<void> setUrl(String url) async {
    calls.add('setUrl:$url');
    final error = setUrlError;
    if (error != null) throw error;
    loadedUrl = url;
    _emit(EngineProcessing.ready);
  }

  @override
  Future<void> play() async {
    calls.add('play');
    _isPlaying = true;
    _emit(EngineProcessing.ready);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    _isPlaying = false;
    _emit(EngineProcessing.ready);
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    _isPlaying = false;
    _emit(EngineProcessing.idle);
  }

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek:${position.inMilliseconds}');
  }

  @override
  Future<void> setSpeed(double speed) async => calls.add('speed:$speed');

  @override
  Future<void> setPitch(double pitch) async => calls.add('pitch:$pitch');

  @override
  Future<void> dispose() async {
    await _position.close();
    await _duration.close();
    await _state.close();
  }

  void complete() => _emit(EngineProcessing.completed);

  void emitPosition(Duration position) => _position.add(position);

  void _emit(EngineProcessing processing) =>
      _state.add(EngineState(isPlaying: _isPlaying, processing: processing));
}
