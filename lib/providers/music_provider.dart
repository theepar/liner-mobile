import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/models/track.dart';

final popularTracksProvider = FutureProvider<List<Track>>((ref) async {
  return await ApiClient.instance.getPopularTracks(period: '7d', limit: 20);
});

final popularTracksAllTimeProvider = FutureProvider<List<Track>>((ref) async {
  return await ApiClient.instance.getPopularTracks(period: 'all', limit: 20);
});

final dailyMixesProvider = FutureProvider<List<Playlist>>((ref) async {
  return await ApiClient.instance.getDailyMixes();
});

final popularArtistsProvider = Provider<List<Artist>>((ref) {
  return ApiClient.defaultArtists();
});

class SearchState {
  final String query;
  final bool isLoading;
  final List<Track> tracks;
  final List<Artist> artists;
  final List<Playlist> playlists;

  const SearchState({
    this.query = '',
    this.isLoading = false,
    this.tracks = const [],
    this.artists = const [],
    this.playlists = const [],
  });

  SearchState copyWith({
    String? query,
    bool? isLoading,
    List<Track>? tracks,
    List<Artist>? artists,
    List<Playlist>? playlists,
  }) =>
      SearchState(
        query: query ?? this.query,
        isLoading: isLoading ?? this.isLoading,
        tracks: tracks ?? this.tracks,
        artists: artists ?? this.artists,
        playlists: playlists ?? this.playlists,
      );
}

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier();
});

class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier() : super(const SearchState());

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = state.copyWith(query: '', tracks: [], artists: [], playlists: []);
      return;
    }
    state = state.copyWith(query: query, isLoading: true);
    try {
      final results = await ApiClient.instance.search(query);
      state = state.copyWith(
        isLoading: false,
        tracks: (results['tracks'] as List<dynamic>?)?.cast<Track>() ?? [],
        artists: (results['artists'] as List<dynamic>?)?.cast<Artist>() ?? [],
        playlists: (results['playlists'] as List<dynamic>?)?.cast<Playlist>() ?? [],
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void clear() {
    state = const SearchState();
  }
}

class SettingsState {
  final String currentBaseUrl;
  final bool isUsingFallback;
  final String audioQuality;

  const SettingsState({
    required this.currentBaseUrl,
    required this.isUsingFallback,
    this.audioQuality = 'high',
  });

  SettingsState copyWith({
    String? currentBaseUrl,
    bool? isUsingFallback,
    String? audioQuality,
  }) =>
      SettingsState(
        currentBaseUrl: currentBaseUrl ?? this.currentBaseUrl,
        isUsingFallback: isUsingFallback ?? this.isUsingFallback,
        audioQuality: audioQuality ?? this.audioQuality,
      );
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier()
      : super(SettingsState(
          currentBaseUrl: ApiClient.instance.baseUrl,
          isUsingFallback: ApiClient.instance.isUsingFallback,
        ));

  Future<void> setBaseUrl(String url) async {
    await ApiClient.instance.setBaseUrl(url);
    state = state.copyWith(
      currentBaseUrl: ApiClient.instance.baseUrl,
      isUsingFallback: ApiClient.instance.isUsingFallback,
    );
  }

  Future<void> probeEndpoint() async {
    await ApiClient.instance.probeEndpoint();
    state = state.copyWith(
      currentBaseUrl: ApiClient.instance.baseUrl,
      isUsingFallback: ApiClient.instance.isUsingFallback,
    );
  }

  void setAudioQuality(String quality) {
    state = state.copyWith(audioQuality: quality);
  }
}
