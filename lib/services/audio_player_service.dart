import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/api/liner_api.dart';
import '../core/models/playback_event.dart';
import '../core/models/player_state.dart';
import '../core/models/track.dart';
import '../core/utils/uuid.dart';
import 'audio_engine.dart';
import 'lyrics_offset_store.dart';
import 'lyrics_session.dart';
import 'playback_telemetry.dart';

class AudioPlayerService {
  AudioPlayerService(
    this._api, {
    AudioEngine? engine,
    this._clock = DateTime.now,
    this._offsets = const PrefsLyricsOffsetStore(),
  }) : _engine = engine ?? JustAudioEngine() {
    _subscriptions.addAll([
      _engine.positionStream.listen(
        (position) => _emit(_currentState.copyWith(position: position)),
      ),
      _engine.durationStream.listen((duration) {
        if (duration != null) {
          _emit(_currentState.copyWith(duration: duration));
        }
      }),
      _engine.stateStream.listen(_onEngineState),
    ]);
  }

  final LinerApi _api;
  final AudioEngine _engine;
  final DateTime Function() _clock;
  final LyricsOffsetStore _offsets;
  LyricsSession? _lyricsSession;
  final _random = Random();
  final _queue = <Track>[];
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _stateController = StreamController<PlayerStateData>.broadcast();
  late final _telemetry = PlaybackTelemetry(onEvent: _report, clock: _clock);

  PlayerStateData _currentState = const PlayerStateData();
  PlaybackContext? _context;
  int _currentIndex = 0;
  int _playRequestId = 0;
  String _waveId = newUuid();
  bool _isFetchingRadio = false;

  bool autoplaySimilar = true;

  Stream<PlayerStateData> get stateStream => _stateController.stream;
  PlayerStateData get currentState => _currentState;

  bool highQuality = false;

  /// iOS requests AAC because AVPlayer cannot decode WebM/Opus.
  String? get _preferredCodec =>
      highQuality || defaultTargetPlatform == TargetPlatform.iOS ? 'aac' : null;

  void _emit(PlayerStateData state) {
    _currentState = state;
    if (!_stateController.isClosed) _stateController.add(state);
  }

  void _onEngineState(EngineState engineState) {
    final processing = engineState.processing;
    final current = _currentState.status;

    if (processing == EngineProcessing.idle &&
        (current == PlaybackStatus.loading ||
            current == PlaybackStatus.error)) {
      return;
    }

    final status = switch (processing) {
      EngineProcessing.loading ||
      EngineProcessing.buffering => PlaybackStatus.loading,
      EngineProcessing.completed => PlaybackStatus.completed,
      _ =>
        engineState.isPlaying ? PlaybackStatus.playing : PlaybackStatus.paused,
    };
    final justCompleted =
        status == PlaybackStatus.completed &&
        current != PlaybackStatus.completed;

    if (status == PlaybackStatus.playing) {
      _telemetry.onPlaying();
    } else {
      _telemetry.onPausedOrStopped();
    }

    _emit(_currentState.copyWith(status: status));
    if (justCompleted) _onTrackCompleted();
  }

  Future<void> setQueue(
    List<Track> tracks, {
    int startIndex = 0,
    PlaybackContext? context,
  }) async {
    if (tracks.isEmpty) return;
    _context = context;
    _waveId = newUuid();
    _queue
      ..clear()
      ..addAll(tracks);
    _currentIndex = startIndex.clamp(0, _queue.length - 1);
    _emit(
      _currentState.copyWith(
        queue: List.unmodifiable(_queue),
        currentIndex: _currentIndex,
      ),
    );
    await _play(_queue[_currentIndex]);
  }

  Future<void> playTrack(Track track, {PlaybackContext? context}) {
    _context = context;
    _waveId = newUuid();
    return _play(track);
  }

  Future<void> skipTo(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    _emit(_currentState.copyWith(currentIndex: index));
    await _play(_queue[index]);
  }

  Future<void> _play(Track track) async {
    final requestId = ++_playRequestId;
    _telemetry.startTrack(track, _context);
    _emit(
      _currentState.copyWith(
        currentTrack: track,
        status: PlaybackStatus.loading,
        position: Duration.zero,
        duration: Duration(milliseconds: track.durationMs),
        clearLyrics: true,
        isLoadingLyrics: true,
      ),
    );
    unawaited(_loadLyrics(track, requestId));
    _maybeTopUpRadio(track, requestId);

    try {
      await _engine.stop();
      final streamUrl = await _api.getStreamUrl(
        track.id,
        preferredCodec: _preferredCodec,
      );
      if (requestId != _playRequestId) return;
      await _engine.setUrl(streamUrl);
      if (requestId != _playRequestId) return;
      unawaited(_startPlayback(requestId));
    } on Exception catch (error) {
      if (requestId != _playRequestId) return;
      developer.log('playTrack(${track.id}) failed: $error', name: 'Player');
      _emit(_currentState.copyWith(status: PlaybackStatus.error));
    }
  }

  /// Keep this detached because AudioEngine.play completes only after playback stops.
  Future<void> _startPlayback(int requestId) async {
    try {
      await _engine.play();
    } on Exception catch (error) {
      if (requestId != _playRequestId) return;
      developer.log('play failed: $error', name: 'Player');
      _emit(_currentState.copyWith(status: PlaybackStatus.error));
    }
  }

  Future<void> _loadLyrics(Track track, int requestId) async {
    final session = LyricsSession(durationMs: track.durationMs);
    _lyricsSession = session;
    unawaited(_restoreLyricsOffset(track.id, session, requestId));

    try {
      await for (final candidate in _api.streamLyrics(track.id)) {
        if (requestId != _playRequestId) return;
        if (session.add(candidate)) _emitLyrics(session);
      }
    } on Exception catch (error) {
      developer.log('lyrics(${track.id}) failed: $error', name: 'Player');
    }
    if (requestId != _playRequestId) return;
    _emitLyrics(session, isLoading: false);
  }

  Future<void> _restoreLyricsOffset(
    String trackId,
    LyricsSession session,
    int requestId,
  ) async {
    final saved = await _offsets.read(trackId);
    if (saved == 0 || requestId != _playRequestId) return;
    session.setOffset(saved);
    _emitLyrics(session);
  }

  void _emitLyrics(LyricsSession session, {bool? isLoading}) {
    _emit(
      _currentState.withLyrics(
        lines: session.lines,
        options: session.options,
        activeProvider: session.activeProvider,
        offsetMs: session.offsetMs,
        plainText: session.plainText,
        isLoading: isLoading,
      ),
    );
  }

  void selectLyricsProvider(String provider) {
    final session = _lyricsSession;
    if (session == null || !session.select(provider)) return;
    _emitLyrics(session);
  }

  Future<void> setLyricsOffset(int offsetMs) async {
    final session = _lyricsSession;
    final track = _currentState.currentTrack;
    if (session == null || track == null) return;
    session.setOffset(offsetMs);
    _emitLyrics(session);
    await _offsets.write(track.id, session.offsetMs);
  }

  void _report(PlaybackEvent event) {
    unawaited(_sendEvent(event));
  }

  Future<void> _sendEvent(PlaybackEvent event) async {
    try {
      await _api.recordPlaybackEvent(event);
    } on Exception catch (error) {
      developer.log('playback event failed: $error', name: 'Player');
    }
  }

  void addToQueue(Track track, {bool next = false}) {
    if (_currentState.currentTrack == null) {
      unawaited(playTrack(track));
      return;
    }
    _ensureQueueHoldsCurrentTrack();
    _queue.insert(next ? _currentIndex + 1 : _queue.length, track);
    _emitQueue();
  }

  Future<void> startRadio(Track seed) =>
      setQueue([seed], context: PlaybackContext('radio', seed.id));

  void _ensureQueueHoldsCurrentTrack() {
    final current = _currentState.currentTrack;
    if (_queue.isEmpty && current != null) {
      _queue.add(current);
      _currentIndex = 0;
    }
  }

  void _emitQueue() {
    _emit(
      _currentState.copyWith(
        queue: List.unmodifiable(_queue),
        currentIndex: _currentIndex,
      ),
    );
  }

  void _maybeTopUpRadio(Track seed, int requestId) {
    if (!autoplaySimilar ||
        _isFetchingRadio ||
        _currentState.repeatMode != LinerRepeatMode.off) {
      return;
    }
    final upcoming = _queue.isEmpty ? 0 : _queue.length - 1 - _currentIndex;
    if (upcoming >= 2) return;
    _isFetchingRadio = true;
    unawaited(_topUpRadio(seed, requestId));
  }

  Future<void> _topUpRadio(Track seed, int requestId) async {
    try {
      _ensureQueueHoldsCurrentTrack();
      final recent = _queue.length > 20
          ? _queue.sublist(_queue.length - 20)
          : _queue;
      final similar = await _api.getRadio(
        seed.id,
        history: [for (final track in recent) track.id],
        waveId: _waveId,
      );
      if (requestId != _playRequestId) return;

      final known = {for (final track in _queue) track.id};
      final additions = [
        for (final track in similar)
          if (known.add(track.id)) track,
      ];
      if (additions.isEmpty) return;
      _queue.addAll(additions);
      _emitQueue();
    } on Exception catch (error) {
      developer.log('radio failed: $error', name: 'Player');
    } finally {
      _isFetchingRadio = false;
    }
  }

  Future<void> play() async {
    final track = _currentState.currentTrack;
    if (track == null) {
      if (_queue.isNotEmpty) await _play(_queue[_currentIndex]);
    } else if (_currentState.hasError) {
      await _play(track);
    } else {
      unawaited(_engine.play());
    }
  }

  Future<void> stop() async {
    _playRequestId++;
    _telemetry.flush();
    _context = null;
    _lyricsSession = null;
    _queue.clear();
    _currentIndex = 0;
    await _engine.stop();
    _emit(const PlayerStateData());
  }

  Future<void> pause() => _engine.pause();

  Future<void> togglePlayPause() => _engine.isPlaying ? pause() : play();

  Future<void> seek(Duration position) {
    if (position < _currentState.position) _telemetry.onSeekBackward();
    return _engine.seek(position);
  }

  Future<void> next() async {
    final target = _nextIndex();
    if (target == null) return;
    await skipTo(target);
  }

  int? _nextIndex() {
    if (_queue.isEmpty) return null;
    if (_currentState.isShuffle && _queue.length > 1) {
      final pick = _random.nextInt(_queue.length - 1);
      return pick >= _currentIndex ? pick + 1 : pick;
    }
    if (_currentIndex < _queue.length - 1) return _currentIndex + 1;
    return _currentState.repeatMode == LinerRepeatMode.all ? 0 : null;
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    if (_currentState.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    await skipTo(_currentIndex > 0 ? _currentIndex - 1 : _queue.length - 1);
  }

  void toggleShuffle() {
    _emit(_currentState.copyWith(isShuffle: !_currentState.isShuffle));
  }

  void cycleRepeatMode() {
    final next = switch (_currentState.repeatMode) {
      LinerRepeatMode.off => LinerRepeatMode.all,
      LinerRepeatMode.all => LinerRepeatMode.one,
      LinerRepeatMode.one => LinerRepeatMode.off,
    };
    _emit(_currentState.copyWith(repeatMode: next));
  }

  Future<void> setSpeed(double speed) async {
    await _engine.setSpeed(speed);
    _emit(_currentState.copyWith(playbackSpeed: speed));
  }

  Future<void> setPitch(double pitch) async {
    await _engine.setPitch(pitch);
    _emit(_currentState.copyWith(pitch: pitch));
  }

  void toggleLyrics() {
    _emit(_currentState.copyWith(isLyricsOpen: !_currentState.isLyricsOpen));
  }

  void _onTrackCompleted() {
    final repeatOne = _currentState.repeatMode == LinerRepeatMode.one;
    _telemetry.onCompleted(repeatOne: repeatOne);
    if (repeatOne) {
      unawaited(_engine.seek(Duration.zero).then((_) => play()));
    } else if (_nextIndex() == null) {
      _telemetry.flush();
    } else {
      unawaited(next());
    }
  }

  Future<void> dispose() async {
    _telemetry.flush();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _engine.dispose();
    await _stateController.close();
  }
}
