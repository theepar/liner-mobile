import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../core/api/liner_api.dart';
import '../core/models/lyric.dart';
import '../core/models/player_state.dart';
import '../core/models/track.dart';

class AudioPlayerService {
  AudioPlayerService(this._api, {AudioPlayer? player})
    : _player = player ?? AudioPlayer() {
    _subscriptions.addAll([
      _player.positionStream.listen(
        (position) => _emit(_currentState.copyWith(position: position)),
      ),
      _player.durationStream.listen((duration) {
        if (duration != null) {
          _emit(_currentState.copyWith(duration: duration));
        }
      }),
      _player.playerStateStream.listen(_onPlayerState),
    ]);
  }

  final LinerApi _api;
  final AudioPlayer _player;
  final _random = Random();
  final _queue = <Track>[];
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _stateController = StreamController<PlayerStateData>.broadcast();

  PlayerStateData _currentState = const PlayerStateData();
  int _currentIndex = 0;
  int _playRequestId = 0;

  Stream<PlayerStateData> get stateStream => _stateController.stream;
  PlayerStateData get currentState => _currentState;

  /// AVPlayer cannot decode WebM/Opus, so iOS asks the server for AAC.
  static String? get _preferredCodec =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'aac' : null;

  void _emit(PlayerStateData state) {
    _currentState = state;
    _stateController.add(state);
  }

  void _onPlayerState(PlayerState playerState) {
    final processingState = playerState.processingState;
    final current = _currentState.status;

    if (processingState == ProcessingState.idle &&
        (current == PlaybackStatus.loading ||
            current == PlaybackStatus.error)) {
      return;
    }

    final status = switch (processingState) {
      ProcessingState.loading ||
      ProcessingState.buffering => PlaybackStatus.loading,
      ProcessingState.completed => PlaybackStatus.completed,
      _ => playerState.playing ? PlaybackStatus.playing : PlaybackStatus.paused,
    };
    final justCompleted =
        status == PlaybackStatus.completed &&
        current != PlaybackStatus.completed;

    _emit(_currentState.copyWith(status: status));
    if (justCompleted) _onTrackCompleted();
  }

  Future<void> setQueue(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
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
    await playTrack(_queue[_currentIndex]);
  }

  Future<void> playTrack(Track track) async {
    final requestId = ++_playRequestId;
    _emit(
      _currentState.copyWith(
        currentTrack: track,
        status: PlaybackStatus.loading,
        position: Duration.zero,
        duration: Duration(milliseconds: track.durationMs),
        lyrics: const <LyricLine>[],
        isLoadingLyrics: true,
      ),
    );
    unawaited(_loadLyrics(track, requestId));

    try {
      await _player.stop();
      final streamUrl = await _api.getStreamUrl(
        track.id,
        preferredCodec: _preferredCodec,
      );
      if (requestId != _playRequestId) return;
      await _player.setUrl(streamUrl);
      if (requestId != _playRequestId) return;
      unawaited(_startPlayback(requestId));
    } on Exception catch (error) {
      if (requestId != _playRequestId) return;
      developer.log('playTrack(${track.id}) failed: $error', name: 'Player');
      _emit(_currentState.copyWith(status: PlaybackStatus.error));
    }
  }

  /// `AudioPlayer.play` completes only when playback pauses or ends, so it
  /// must never be awaited by callers.
  Future<void> _startPlayback(int requestId) async {
    try {
      await _player.play();
    } on Exception catch (error) {
      if (requestId != _playRequestId) return;
      developer.log('play failed: $error', name: 'Player');
      _emit(_currentState.copyWith(status: PlaybackStatus.error));
    }
  }

  Future<void> _loadLyrics(Track track, int requestId) async {
    var lyrics = const <LyricLine>[];
    try {
      lyrics = await _api.getLyrics(track.id, durationMs: track.durationMs);
    } on Exception catch (error) {
      developer.log('lyrics(${track.id}) failed: $error', name: 'Player');
    }
    if (requestId != _playRequestId) return;
    _emit(_currentState.copyWith(lyrics: lyrics, isLoadingLyrics: false));
  }

  Future<void> play() async {
    final track = _currentState.currentTrack;
    if (track == null) {
      if (_queue.isNotEmpty) await playTrack(_queue[_currentIndex]);
    } else if (_currentState.hasError) {
      await playTrack(track);
    } else {
      unawaited(_player.play());
    }
  }

  Future<void> stop() async {
    _playRequestId++;
    _queue.clear();
    _currentIndex = 0;
    await _player.stop();
    _emit(const PlayerStateData());
  }

  Future<void> pause() => _player.pause();

  Future<void> togglePlayPause() => _player.playing ? pause() : play();

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> next() async {
    final target = _nextIndex();
    if (target == null) return;
    _currentIndex = target;
    _emit(_currentState.copyWith(currentIndex: target));
    await playTrack(_queue[target]);
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
    _currentIndex = _currentIndex > 0 ? _currentIndex - 1 : _queue.length - 1;
    _emit(_currentState.copyWith(currentIndex: _currentIndex));
    await playTrack(_queue[_currentIndex]);
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
    await _player.setSpeed(speed);
    _emit(_currentState.copyWith(playbackSpeed: speed));
  }

  Future<void> setPitch(double pitch) async {
    await _player.setPitch(pitch);
    _emit(_currentState.copyWith(pitch: pitch));
  }

  void toggleLyrics() {
    _emit(_currentState.copyWith(isLyricsOpen: !_currentState.isLyricsOpen));
  }

  void _onTrackCompleted() {
    if (_currentState.repeatMode == LinerRepeatMode.one) {
      unawaited(seek(Duration.zero).then((_) => play()));
    } else {
      unawaited(next());
    }
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
    await _stateController.close();
  }
}
