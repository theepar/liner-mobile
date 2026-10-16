import 'dart:convert';

import '../models/artist.dart';
import '../models/json_helpers.dart';
import '../models/lyric.dart';
import '../models/playlist.dart';
import '../models/search_results.dart';
import '../models/track.dart';
import '../utils/lyric_parser.dart';
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

  static const _syncRank = {
    'syllable_level': 3,
    'word_level': 2,
    'line_level': 1,
  };
  static const _supportedLyricFormats = {'richsync', 'lrc'};
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

  Future<Playlist> createPlaylist(String title) async {
    final data = asMap(
      await _client.post('/v1/me/playlists', body: {'title': title}),
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

  Future<List<Artist>> getFollowedArtists() async {
    final data = await _client.get('/v1/me/library/artists');
    return parseList(
      asMap(data)?['items'],
      (item) => Artist.fromJson(asMap(item['artist']) ?? item),
    );
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

  /// Reads the lyrics provider stream and returns the best time-synced
  /// candidate (syllable > word > line), or an empty list when none exists.
  Future<List<LyricLine>> getLyrics(
    String trackId, {
    int durationMs = 0,
  }) async {
    String? bestContent;
    var bestRank = 0;
    num bestQuality = -1;

    final events = _client
        .getEventStream('/v1/tracks/${Uri.encodeComponent(trackId)}/lyrics')
        .timeout(_lyricsTimeout, onTimeout: (sink) => sink.close());

    await for (final payload in events) {
      final event = asMap(_tryDecode(payload));
      if (event == null ||
          event['type'] != 'provider' ||
          event['status'] != 'found') {
        continue;
      }
      final candidate = asMap(event['candidate']);
      final lyrics = asMap(candidate?['lyrics']);
      final content = asString(lyrics?['content']);
      if (candidate == null ||
          content == null ||
          content.trim().isEmpty ||
          !_supportedLyricFormats.contains(asString(lyrics?['format']))) {
        continue;
      }

      final rank = _syncRank[asString(candidate['syncLevel'])] ?? 0;
      final quality = switch (asMap(candidate['quality'])?['total']) {
        final num total => total,
        _ => 0,
      };
      if (rank > bestRank || (rank == bestRank && quality > bestQuality)) {
        bestContent = content;
        bestRank = rank;
        bestQuality = quality;
      }
      if (bestRank == _syncRank['syllable_level']) break;
    }

    if (bestContent == null) return const [];
    return LyricParser.parse(bestContent, songDurationMs: durationMs);
  }

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
