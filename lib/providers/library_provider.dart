import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/api/liner_api.dart';
import '../core/models/artist.dart';
import '../core/models/playlist.dart';
import '../core/models/track.dart';
import 'api_provider.dart';
import 'auth_provider.dart';

final userPlaylistsProvider = FutureProvider<List<Playlist>>((ref) {
  ref.watch(userIdProvider);
  return ref.watch(linerApiProvider).getPlaylists();
});

final followedArtistsProvider = FutureProvider<List<Artist>>((ref) {
  ref.watch(userIdProvider);
  return ref.watch(linerApiProvider).getFollowedArtists();
});

final likedTracksProvider =
    StateNotifierProvider<LikedTracksNotifier, LikedTracksState>((ref) {
      ref.watch(userIdProvider);
      return LikedTracksNotifier(ref.watch(linerApiProvider));
    });

final likedTrackIdsProvider = Provider<Set<String>>(
  (ref) => ref.watch(likedTracksProvider.select((state) => state.ids)),
);

class LikedTracksState {
  const LikedTracksState({
    this.tracks = const [],
    this.ids = const {},
    this.isLoading = true,
    this.hasError = false,
  });

  final List<Track> tracks;
  final Set<String> ids;
  final bool isLoading;
  final bool hasError;
}

class LikedTracksNotifier extends StateNotifier<LikedTracksState> {
  LikedTracksNotifier(this._api) : super(const LikedTracksState()) {
    unawaited(refresh());
  }

  final LinerApi _api;

  Future<void> refresh() async {
    state = const LikedTracksState();
    try {
      final tracks = await _api.getLikedTracks();
      if (!mounted) return;
      state = _stateFor(tracks);
    } on ApiException catch (error) {
      developer.log('liked tracks failed: $error', name: 'Library');
      if (!mounted) return;
      state = const LikedTracksState(isLoading: false, hasError: true);
    }
  }

  /// Optimistically flips the like, restoring the previous state and
  /// rethrowing if the server rejects the change.
  Future<void> toggle(Track track) async {
    final previous = state;
    final wasLiked = previous.ids.contains(track.id);
    state = _stateFor(
      wasLiked
          ? [
              for (final t in previous.tracks)
                if (t.id != track.id) t,
            ]
          : [track, ...previous.tracks],
    );
    try {
      if (wasLiked) {
        await _api.unlikeTrack(track.id);
      } else {
        await _api.likeTrack(track.id);
      }
    } on ApiException {
      if (mounted) state = previous;
      rethrow;
    }
  }

  static LikedTracksState _stateFor(List<Track> tracks) => LikedTracksState(
    tracks: tracks,
    ids: {for (final track in tracks) track.id},
    isLoading: false,
  );
}
