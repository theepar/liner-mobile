import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/api/liner_api.dart';
import '../core/models/album.dart';
import '../core/models/artist.dart';
import '../core/models/artist_details.dart';
import '../core/models/collection_type.dart';
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

final savedAlbumsProvider = FutureProvider<List<Album>>((ref) {
  ref.watch(userIdProvider);
  return ref.watch(linerApiProvider).getSavedAlbums();
});

final savedPlaylistsProvider = FutureProvider<List<Playlist>>((ref) {
  ref.watch(userIdProvider);
  return ref.watch(linerApiProvider).getSavedPlaylists();
});

final savedIdsProvider = Provider.family<Set<String>, CollectionType>(
  (ref, type) => switch (type) {
    CollectionType.albums => {
      for (final album
          in ref.watch(savedAlbumsProvider).valueOrNull ?? const <Album>[])
        album.id,
    },
    CollectionType.artists => {
      for (final artist
          in ref.watch(followedArtistsProvider).valueOrNull ?? const <Artist>[])
        artist.id,
    },
    CollectionType.playlists => {
      for (final playlist
          in ref.watch(savedPlaylistsProvider).valueOrNull ??
              const <Playlist>[])
        playlist.id,
    },
  },
);

final artistDetailsProvider = FutureProvider.autoDispose
    .family<ArtistDetails, String>((ref, id) {
      ref.watch(userIdProvider);
      return ref.watch(linerApiProvider).getArtist(id);
    });

final albumProvider = FutureProvider.autoDispose.family<Album, String>((
  ref,
  id,
) {
  ref.watch(userIdProvider);
  return ref.watch(linerApiProvider).getAlbum(id);
});

final catalogPlaylistProvider = FutureProvider.autoDispose
    .family<Playlist, String>((ref, id) {
      ref.watch(userIdProvider);
      return ref.watch(linerApiProvider).getCatalogPlaylist(id);
    });

final userPlaylistProvider = FutureProvider.autoDispose
    .family<UserPlaylistDetails, String>((ref, id) {
      ref.watch(userIdProvider);
      return ref.watch(linerApiProvider).getUserPlaylist(id);
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
