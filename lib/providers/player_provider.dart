import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/player_state.dart';
import '../core/models/track.dart';
import '../services/audio_player_service.dart';
import 'api_provider.dart';
import 'auth_provider.dart';

final playerServiceProvider = Provider<AudioPlayerService>((ref) {
  final service = AudioPlayerService(ref.watch(linerApiProvider));
  ref.listen<String?>(userIdProvider, (_, userId) {
    if (userId == null) unawaited(service.stop());
  });
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

final playerStateProvider =
    StateNotifierProvider<PlayerNotifier, PlayerStateData>(
      (ref) => PlayerNotifier(ref.watch(playerServiceProvider)),
    );

final currentTrackIdProvider = Provider<String?>(
  (ref) =>
      ref.watch(playerStateProvider.select((state) => state.currentTrack?.id)),
);

class PlayerNotifier extends StateNotifier<PlayerStateData> {
  PlayerNotifier(this._service) : super(_service.currentState) {
    _subscription = _service.stateStream.listen((next) => state = next);
  }

  final AudioPlayerService _service;
  late final StreamSubscription<PlayerStateData> _subscription;

  Future<void> playTrack(Track track, [List<Track>? queue, int? index]) {
    if (queue == null || queue.isEmpty) return _service.playTrack(track);
    final start = index ?? queue.indexWhere((t) => t.id == track.id);
    if (start < 0) return _service.playTrack(track);
    return _service.setQueue(queue, startIndex: start);
  }

  Future<void> playAll(List<Track> tracks) =>
      tracks.isEmpty ? Future.value() : _service.setQueue(tracks);

  Future<void> togglePlayPause() => _service.togglePlayPause();
  Future<void> next() => _service.next();
  Future<void> previous() => _service.previous();
  Future<void> seek(Duration position) => _service.seek(position);
  Future<void> setSpeed(double speed) => _service.setSpeed(speed);
  Future<void> setPitch(double pitch) => _service.setPitch(pitch);
  void toggleShuffle() => _service.toggleShuffle();
  void cycleRepeatMode() => _service.cycleRepeatMode();
  void toggleLyrics() => _service.toggleLyrics();

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
