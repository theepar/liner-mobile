import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/api/liner_api.dart';
import '../core/models/album.dart';
import '../core/models/artist.dart';
import '../core/models/playlist.dart';
import '../core/models/track.dart';
import 'api_provider.dart';

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>(
  (ref) => SearchNotifier(ref.watch(linerApiProvider)),
);

class SearchState {
  const SearchState({
    this.query = '',
    this.isLoading = false,
    this.hasError = false,
    this.tracks = const [],
    this.artists = const [],
    this.albums = const [],
    this.playlists = const [],
  });

  final String query;
  final bool isLoading;
  final bool hasError;
  final List<Track> tracks;
  final List<Artist> artists;
  final List<Album> albums;
  final List<Playlist> playlists;

  bool get hasResults =>
      tracks.isNotEmpty ||
      artists.isNotEmpty ||
      albums.isNotEmpty ||
      playlists.isNotEmpty;
}

class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier(this._api, {this.debounce = const Duration(milliseconds: 350)})
    : super(const SearchState());

  final LinerApi _api;
  final Duration debounce;
  Timer? _debounceTimer;
  int _requestId = 0;

  /// Debounced; results of superseded queries are discarded.
  void search(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      clear();
      return;
    }
    state = SearchState(query: query, isLoading: true);
    _debounceTimer = Timer(debounce, () => unawaited(_run(trimmed)));
  }

  Future<void> _run(String query) async {
    final requestId = ++_requestId;
    try {
      final results = await _api.search(query);
      if (!mounted || requestId != _requestId) return;
      state = SearchState(
        query: state.query,
        tracks: results.tracks,
        artists: results.artists,
        albums: results.albums,
        playlists: results.playlists,
      );
    } on ApiException catch (error) {
      developer.log('search failed: $error', name: 'Search');
      if (!mounted || requestId != _requestId) return;
      state = SearchState(query: state.query, hasError: true);
    }
  }

  void clear() {
    _debounceTimer?.cancel();
    _requestId++;
    state = const SearchState();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
