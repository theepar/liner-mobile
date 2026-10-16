import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/player_state.dart';
import '../core/models/track.dart';
import '../services/audio_player_service.dart';

final playerServiceProvider = Provider<AudioPlayerService>((ref) {
  return AudioPlayerService.instance;
});

final playerStateProvider = StateNotifierProvider<PlayerNotifier, PlayerStateData>((ref) {
  final service = ref.watch(playerServiceProvider);
  return PlayerNotifier(service);
});

class PlayerNotifier extends StateNotifier<PlayerStateData> {
  final AudioPlayerService _service;

  PlayerNotifier(this._service) : super(_service.currentState) {
    _service.stateStream.listen((newState) {
      state = newState;
    });
  }

  Future<void> playTrack(Track track, [List<Track>? queue, int? index]) async {
    if (queue != null && queue.isNotEmpty) {
      await _service.setQueue(queue, startIndex: index ?? queue.indexOf(track));
    } else {
      await _service.playTrack(track);
    }
  }

  Future<void> togglePlayPause() => _service.togglePlayPause();
  Future<void> next() => _service.next();
  Future<void> previous() => _service.previous();
  Future<void> seek(Duration position) => _service.seek(position);
  void toggleShuffle() => _service.toggleShuffle();
  void cycleRepeatMode() => _service.cycleRepeatMode();
  Future<void> setSpeed(double speed) => _service.setSpeed(speed);
  Future<void> setPitch(double pitch) => _service.setPitch(pitch);
  void toggleLyrics() => _service.toggleLyrics();
  void toggleLike(String trackId) => _service.toggleLike(trackId);
}
