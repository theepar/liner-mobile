import 'dart:convert';

import '../models/album.dart';
import '../models/artist.dart';
import '../models/artist_details.dart';
import '../models/collection_type.dart';
import '../models/json_helpers.dart';
import '../models/lyric.dart';
import '../models/playback_event.dart';
import '../models/playlist.dart';
import '../models/playlist_import.dart';
import '../models/search_results.dart';
import '../models/track.dart';
import 'api_client.dart';

class StreamUnavailableException implements Exception {
  const StreamUnavailableException(this.trackId);

  final String trackId;

  @override
  String toString() => 'No playable stream for track $trackId';
}

class LinerApi {
  const LinerApi(this._client);

  final ApiClient _client;

  static const _lyricsTimeout = Duration(seconds: 20);

  Future<List<Track>> getPopularTracks({
    String window = '7d',
    int limit = 20,
  }) async {
    final data = await _client.get(
      '/v1/explore/popular',
      query: {'window': window, 'limit': limit},
    );
    return _tracksFromItems(asMap(data)?['items']);
  }

  Future<List<Track>> getRecentlyPlayed({int limit = 30}) async {
    final data = await _client.get('/v1/me/history', query: {'limit': limit});
    final seen = <String>{};
    return [
      for (final track in _tracksFromItems(asMap(data)?['items']))
        if (seen.add(track.id)) track,
    ];
  }

  Future<List<Playlist>> getDailyMixes() async {
    final data = await _client.get('/v1/me/recommendations/daily-mixes');
    return parseList(asMap(data)?['items'], Playlist.fromJson);
  }

  Future<SearchResults> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return SearchResults.empty;
    final data = await _client.get(
      '/v1/search',
      query: {'q': trimmed, 'type': 'all'},
    );
    final json = asMap(data);
    return json == null ? SearchResults.empty : SearchResults.fromJson(json);
  }

  Future<List<Track>> getLikedTracks({
    int pageSize = 100,
    int maxPages = 10,
  }) async {
    final tracks = <Track>[];
    String? cursor;
    for (var page = 0; page < maxPages; page++) {
      final data = asMap(
        await _client.get(
          '/v1/me/library/tracks',
          query: {'limit': pageSize, 'cursor': ?cursor},
        ),
      );
      tracks.addAll(_tracksFromItems(data?['items']));
      cursor = asString(data?['nextCursor']);
      if (cursor == null) break;
    }
    return tracks;
  }

  Future<void> likeTrack(String trackId) =>
      _client.put('/v1/me/library/tracks/${Uri.encodeComponent(trackId)}');

  Future<void> unlikeTrack(String trackId) =>
      _client.delete('/v1/me/library/tracks/${Uri.encodeComponent(trackId)}');

  Future<List<Playlist>> getPlaylists() async {
    final data = await _client.get('/v1/me/playlists');
    return parseList(asMap(data)?['items'], Playlist.fromJson);
  }

  Future<Playlist> createPlaylist(String title, {String? description}) async {
    final data = asMap(
      await _client.post(
        '/v1/me/playlists',
        body: {'title': title, 'description': ?description},
      ),
    );
    if (data == null) {
      throw const ApiException('The server returned an invalid playlist.');
    }
    return Playlist.fromJson(data);
  }

  Future<List<Track>> getPlaylistTracks(String playlistId) async {
    final data = await _client.get(
      '/v1/me/playlists/${Uri.encodeComponent(playlistId)}',
    );
    return _tracksFromItems(asMap(data)?['items']);
  }

  Future<UserPlaylistDetails> getUserPlaylist(String playlistId) async {
    final data = asMap(
      await _client.get('/v1/me/playlists/${Uri.encodeComponent(playlistId)}'),
    );
    if (data == null) {
      throw const ApiException('The server returned an invalid playlist.');
    }
    return UserPlaylistDetails.fromJson(data);
  }

  Future<void> addTrackToPlaylist(String playlistId, String trackId) =>
      _client.post(
        '/v1/me/playlists/${Uri.encodeComponent(playlistId)}'
        '/tracks/${Uri.encodeComponent(trackId)}',
      );

  Future<void> removePlaylistItem(String playlistId, String itemId) =>
      _client.delete(
        '/v1/me/playlists/${Uri.encodeComponent(playlistId)}'
        '/items/${Uri.encodeComponent(itemId)}',
      );

  Future<void> deletePlaylist(String playlistId) =>
      _client.delete('/v1/me/playlists/${Uri.encodeComponent(playlistId)}');

  Future<void> updatePlaylist(
    String playlistId, {
    String? title,
    String? description,
  }) => _client.patch(
    '/v1/me/playlists/${Uri.encodeComponent(playlistId)}',
    body: {'title': ?title, 'description': ?description},
  );

  Future<Track> getTrack(String trackId) async {
    final data = asMap(
      await _client.get('/v1/tracks/${Uri.encodeComponent(trackId)}'),
    );
    if (data == null) throw const ApiException('Track not found.');
    return Track.fromJson(data);
  }

  Future<ArtistDetails> getArtist(String artistId) async {
    final data = asMap(
      await _client.get('/v1/artists/${Uri.encodeComponent(artistId)}'),
    );
    if (data == null) throw const ApiException('Artist not found.');
    return ArtistDetails.fromJson(data);
  }

  Future<Album> getAlbum(String albumId) async {
    final data = asMap(
      await _client.get('/v1/albums/${Uri.encodeComponent(albumId)}'),
    );
    if (data == null) throw const ApiException('Album not found.');
    return Album.fromJson(data);
  }

  Future<Playlist> getCatalogPlaylist(String playlistId) async {
    final data = asMap(
      await _client.get('/v1/playlists/${Uri.encodeComponent(playlistId)}'),
    );
    if (data == null) throw const ApiException('Playlist not found.');
    return Playlist.fromJson(data);
  }

  Future<List<Artist>> getFollowedArtists() =>
      _savedCollection(CollectionType.artists, Artist.fromJson);

  Future<List<Album>> getSavedAlbums() =>
      _savedCollection(CollectionType.albums, Album.fromJson);

  Future<List<Playlist>> getSavedPlaylists() =>
      _savedCollection(CollectionType.playlists, Playlist.fromJson);

  Future<void> saveCollection(CollectionType type, String id) =>
      _client.put('/v1/me/library/${type.path}/${Uri.encodeComponent(id)}');

  Future<void> removeCollection(CollectionType type, String id) =>
      _client.delete('/v1/me/library/${type.path}/${Uri.encodeComponent(id)}');

  Future<List<T>> _savedCollection<T>(
    CollectionType type,
    T Function(JsonMap json) parse,
  ) async {
    final data = await _client.get('/v1/me/library/${type.path}');
    return parseList(
      asMap(data)?['items'],
      (entry) => parse(asMap(entry[type.entryKey]) ?? entry),
    );
  }

  /// Tracks similar to [trackId]; [history] lets the server avoid repeats and
  /// [waveId] keeps successive pages of one station coherent.
  Future<List<Track>> getRadio(
    String trackId, {
    List<String> history = const [],
    int count = 20,
    String? waveId,
  }) async {
    final path = '/v1/tracks/${Uri.encodeComponent(trackId)}/radio';
    final data = history.isEmpty
        ? await _client.get(path, query: {'k': count, 'wave_id': ?waveId})
        : await _client.post(
            path,
            body: {'history': history, 'k': count, 'wave_id': ?waveId},
          );
    return parseList(asMap(data)?['items'], Track.fromJson);
  }

  /// Uses the `proxy` transport, which returns a plain stream URL. The
  /// `direct_innertube` transport returns an InnerTube request plan instead.
  Future<String> getStreamUrl(String trackId, {String? preferredCodec}) async {
    final data = asMap(
      await _client.post(
        '/v1/tracks/${Uri.encodeComponent(trackId)}/playback',
        body: {'transport': 'proxy', 'preferredCodec': ?preferredCodec},
      ),
    );
    final streamUrl = asString(data?['streamUrl']);
    if (streamUrl == null || streamUrl.isEmpty) {
      throw StreamUnavailableException(trackId);
    }
    return _client.resolveUrl(streamUrl);
  }

  /// Every provider's lyrics as they arrive on the lyrics stream, until the
  /// server reports it is done or [_lyricsTimeout] passes.
  Stream<LyricsCandidate> streamLyrics(String trackId) async* {
    final events = _client
        .getEventStream('/v1/tracks/${Uri.encodeComponent(trackId)}/lyrics')
        .timeout(_lyricsTimeout, onTimeout: (sink) => sink.close());
    await for (final payload in events) {
      final event = asMap(_tryDecode(payload));
      if (event == null) continue;
      if (event['type'] == 'done') return;
      final candidate = LyricsCandidate.fromEvent(event);
      if (candidate != null) yield candidate;
    }
  }

  Future<ImportJob> createPlaylistImport(String url) async => _importJob(
    await _client.post('/v1/me/playlist-imports', body: {'url': url}),
  );

  Future<ImportJob> getPlaylistImport(String importId) async => _importJob(
    await _client.get(
      '/v1/me/playlist-imports/${Uri.encodeComponent(importId)}',
    ),
  );

  Future<List<ImportReview>> getPlaylistImportReview(String importId) async {
    final data = await _client.get(
      '/v1/me/playlist-imports/${Uri.encodeComponent(importId)}/review',
    );
    return [
      for (final item in asList(asMap(data)?['items']) ?? const <Object?>[])
        ?ImportReview.tryParse(item),
    ];
  }

  /// Returns whether the server finalized the playlist right away.
  Future<bool> decidePlaylistImportReview(
    String importId, {
    required List<ImportReviewDecision> decisions,
    required List<JsonMap> approvedTracks,
    String? title,
    String? description,
  }) => _submitImportReview(importId, {
    'decisions': [for (final decision in decisions) decision.toJson()],
    'tracks': approvedTracks,
    'title': ?title,
    'description': ?description,
  });

  /// Finishes the import with only the tracks that were matched automatically.
  Future<bool> skipPlaylistImportReview(
    String importId, {
    List<JsonMap> approvedTracks = const [],
    String? title,
    String? description,
  }) => _submitImportReview(importId, {
    'action': 'skip',
    if (approvedTracks.isNotEmpty) 'tracks': approvedTracks,
    'title': ?title,
    'description': ?description,
  });

  Future<bool> _submitImportReview(String importId, JsonMap body) async {
    final data = await _client.post(
      '/v1/me/playlist-imports/${Uri.encodeComponent(importId)}/review',
      body: body,
    );
    return asBool(asMap(data)?['finalized']) ?? false;
  }

  static ImportJob _importJob(Object? data) {
    final json = asMap(data);
    if (json == null) {
      throw const ApiException('The server returned an invalid import job.');
    }
    return ImportJob.fromJson(json);
  }

  Future<void> recordPlaybackEvent(PlaybackEvent event) =>
      _client.post('/v1/me/playback/events', body: event.toJson());

  static List<Track> _tracksFromItems(Object? items) =>
      parseList(items, (item) => Track.fromJson(asMap(item['track']) ?? item));

  static Object? _tryDecode(String payload) {
    try {
      return jsonDecode(payload);
    } on FormatException {
      return null;
    }
  }
}
