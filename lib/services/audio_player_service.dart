import 'dart:async';
import 'package:just_audio/just_audio.dart';
import '../core/models/track.dart';
import '../core/models/player_state.dart';
import '../core/api/api_client.dart';

class AudioPlayerService {
  static AudioPlayerService? _instance;
  final AudioPlayer _player = AudioPlayer();

  final List<Track> _queue = [];
  int _currentIndex = 0;
  bool _isShuffle = false;
  LinerRepeatMode _repeatMode = LinerRepeatMode.off;

  final _playerStateController = StreamController<PlayerStateData>.broadcast();
  Stream<PlayerStateData> get stateStream => _playerStateController.stream;

  PlayerStateData _currentState = const PlayerStateData();
  PlayerStateData get currentState => _currentState;

  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _statusSub;

  AudioPlayerService._() {
    _initListeners();
  }

  static AudioPlayerService get instance => _instance ??= AudioPlayerService._();

  void _initListeners() {
    _posSub = _player.positionStream.listen((pos) {
      _updateState(_currentState.copyWith(position: pos));
    });

    _durSub = _player.durationStream.listen((dur) {
      if (dur != null) {
        _updateState(_currentState.copyWith(duration: dur));
      }
    });

    _statusSub = _player.playerStateStream.listen((ps) {
      PlaybackStatus status;
      if (ps.processingState == ProcessingState.loading ||
          ps.processingState == ProcessingState.buffering) {
        status = PlaybackStatus.loading;
      } else if (ps.processingState == ProcessingState.completed) {
        status = PlaybackStatus.completed;
        _onTrackCompleted();
      } else if (ps.playing) {
        status = PlaybackStatus.playing;
      } else {
        status = PlaybackStatus.paused;
      }
      _updateState(_currentState.copyWith(status: status));
    });
  }

  void _updateState(PlayerStateData newState) {
    _currentState = newState;
    _playerStateController.add(_currentState);
  }

  Future<void> setQueue(List<Track> tracks, {int startIndex = 0}) async {
    _queue.clear();
    _queue.addAll(tracks);
    _currentIndex = startIndex.clamp(0, _queue.isNotEmpty ? _queue.length - 1 : 0);

    _updateState(_currentState.copyWith(
      queue: List.unmodifiable(_queue),
      currentIndex: _currentIndex,
    ));

    if (_queue.isNotEmpty) {
      await playTrack(_queue[_currentIndex]);
    }
  }

  Future<void> playTrack(Track track) async {
    try {
      _updateState(_currentState.copyWith(
        currentTrack: track,
        status: PlaybackStatus.loading,
        position: Duration.zero,
        duration: Duration(milliseconds: track.durationMs),
      ));

      // Resolve stream URL
      String streamUrl = track.streamUrl ?? '';
      if (streamUrl.isEmpty) {
        streamUrl = await ApiClient.instance.getPlaybackStreamUrl(track.id);
      }

      await _player.setUrl(streamUrl);
      await _player.play();

      // Fetch lyrics in background
      _loadLyricsForTrack(track.id, track.durationMs);
    } catch (e) {
      // In case of playback failure, mark as paused
      _updateState(_currentState.copyWith(status: PlaybackStatus.paused));
    }
  }

  Future<void> _loadLyricsForTrack(String trackId, int durationMs) async {
    _updateState(_currentState.copyWith(isLoadingLyrics: true));
    try {
      final lyrics = await ApiClient.instance.getLyrics(trackId, durationMs: durationMs);
      _updateState(_currentState.copyWith(
        lyrics: lyrics,
        isLoadingLyrics: false,
      ));
    } catch (_) {
      _updateState(_currentState.copyWith(isLoadingLyrics: false));
    }
  }

  Future<void> play() async {
    if (_currentState.currentTrack == null && _queue.isNotEmpty) {
      await playTrack(_queue[_currentIndex]);
    } else {
      await _player.play();
    }
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
    } else {
      if (_repeatMode == LinerRepeatMode.all) {
        _currentIndex = 0;
      } else {
        return;
      }
    }
    _updateState(_currentState.copyWith(currentIndex: _currentIndex));
    await playTrack(_queue[_currentIndex]);
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    if (_currentState.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    if (_currentIndex > 0) {
      _currentIndex--;
    } else {
      _currentIndex = _queue.length - 1;
    }
    _updateState(_currentState.copyWith(currentIndex: _currentIndex));
    await playTrack(_queue[_currentIndex]);
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    _updateState(_currentState.copyWith(isShuffle: _isShuffle));
  }

  void cycleRepeatMode() {
    switch (_repeatMode) {
      case LinerRepeatMode.off:
        _repeatMode = LinerRepeatMode.all;
        break;
      case LinerRepeatMode.all:
        _repeatMode = LinerRepeatMode.one;
        break;
      case LinerRepeatMode.one:
        _repeatMode = LinerRepeatMode.off;
        break;
    }
    _updateState(_currentState.copyWith(repeatMode: _repeatMode));
  }

  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
    _updateState(_currentState.copyWith(playbackSpeed: speed));
  }

  Future<void> setPitch(double pitch) async {
    await _player.setPitch(pitch);
    _updateState(_currentState.copyWith(pitch: pitch));
  }

  void toggleLyrics() {
    _updateState(_currentState.copyWith(isLyricsOpen: !_currentState.isLyricsOpen));
  }

  void toggleLike(String trackId) {
    final currentLikes = Set<String>.from(_currentState.likedTrackIds);
    if (currentLikes.contains(trackId)) {
      currentLikes.remove(trackId);
    } else {
      currentLikes.add(trackId);
    }
    _updateState(_currentState.copyWith(likedTrackIds: currentLikes));
  }

  void _onTrackCompleted() {
    if (_repeatMode == LinerRepeatMode.one) {
      seek(Duration.zero).then((_) => play());
    } else {
      next();
    }
  }

  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _statusSub?.cancel();
    _player.dispose();
    _playerStateController.close();
  }
}
