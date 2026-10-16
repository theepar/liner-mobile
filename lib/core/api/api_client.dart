import 'dart:async';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';
import '../utils/lyric_parser.dart';

const String kPrimaryApiUrl = 'https://api.tryliner.fun';
const String kFallbackEdgeUrl = 'http://edge.tryliner.fun:10518';
const String _kApiUrlPrefKey = 'liner_api_base_url';
const String _kTokenPrefKey = 'liner_auth_token';

class ApiClient {
  static ApiClient? _instance;
  late final Dio _dio;
  String _baseUrl = kPrimaryApiUrl;
  bool _isUsingFallback = false;

  ApiClient._() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'x-client-version': '1.0.4-mobile',
        'x-platform': 'flutter-mobile',
      },
    ));
    _dio.interceptors.add(_AuthInterceptor());
  }

  static ApiClient get instance => _instance ??= ApiClient._();

  String get baseUrl => _baseUrl;
  bool get isUsingFallback => _isUsingFallback;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_kApiUrlPrefKey);
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _baseUrl = savedUrl;
      _dio.options.baseUrl = _baseUrl;
    } else {
      await probeEndpoint();
    }
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url.replaceAll(RegExp(r'/+$'), '');
    _dio.options.baseUrl = _baseUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kApiUrlPrefKey, _baseUrl);
  }

  Future<String> probeEndpoint() async {
    try {
      final probeDio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
      ));
      final res = await probeDio.get('$kPrimaryApiUrl/health');
      if (res.statusCode == 200) {
        _baseUrl = kPrimaryApiUrl;
        _isUsingFallback = false;
        _dio.options.baseUrl = _baseUrl;
        return _baseUrl;
      }
    } catch (_) {
      // Primary failed, use fallback edge
    }

    _baseUrl = kFallbackEdgeUrl;
    _isUsingFallback = true;
    _dio.options.baseUrl = _baseUrl;
    return _baseUrl;
  }

  // ── Popular Tracks ────────────────────────────────────────────────
  Future<List<Track>> getPopularTracks({String period = '7d', int limit = 20}) async {
    try {
      final res = await _dio.get(
        '/v1/tracks/popular',
        queryParameters: {'period': period, 'limit': limit},
      );
      if (res.data is Map && res.data['items'] is List) {
        final items = res.data['items'] as List<dynamic>;
        return items.map((e) {
          final tData = e['track'] ?? e;
          final t = Track.fromJson(tData as Map<String, dynamic>);
          return t.copyWith(
            playCount: (e['playCount'] as num?)?.toInt() ?? t.playCount,
          );
        }).toList();
      } else if (res.data is List) {
        return (res.data as List).map((e) => Track.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {
      // Graceful fallback to rich mock data
    }
    return getFallbackPopularTracks();
  }

  // ── Daily Mixes ──────────────────────────────────────────────────
  Future<List<Playlist>> getDailyMixes() async {
    try {
      final res = await _dio.get('/v1/me/daily-mixes');
      if (res.data is Map && res.data['items'] is List) {
        return (res.data['items'] as List)
            .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (res.data is List) {
        return (res.data as List).map((e) => Playlist.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return getFallbackDailyMixes();
  }

  // ── Search ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>> search(String query) async {
    if (query.trim().isEmpty) {
      return {'tracks': <Track>[], 'artists': <Artist>[], 'playlists': <Playlist>[]};
    }
    try {
      final res = await _dio.get('/v1/search', queryParameters: {'q': query, 'type': 'all'});
      final data = res.data as Map<String, dynamic>;
      
      final tracks = (data['tracks']?['items'] as List<dynamic>?)
              ?.map((e) => Track.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      final artists = (data['artists']?['items'] as List<dynamic>?)
              ?.map((e) => Artist.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      final playlists = (data['playlists']?['items'] as List<dynamic>?)
              ?.map((e) => Playlist.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];

      return {'tracks': tracks, 'artists': artists, 'playlists': playlists};
    } catch (_) {
      // Filter fallback tracks by query
      final all = getFallbackPopularTracks();
      final filtered = all
          .where((t) =>
              t.title.toLowerCase().contains(query.toLowerCase()) ||
              t.artistName.toLowerCase().contains(query.toLowerCase()))
          .toList();
      return {'tracks': filtered, 'artists': <Artist>[], 'playlists': <Playlist>[]};
    }
  }

  // ── Track Stream URL ─────────────────────────────────────────────
  Future<String> getPlaybackStreamUrl(String trackId) async {
    try {
      final res = await _dio.post(
        '/v1/tracks/$trackId/playback',
        data: {'preferredCodec': 'opus', 'transport': 'direct_innertube'},
      );
      if (res.data is Map && res.data['url'] != null) {
        return res.data['url'] as String;
      }
    } catch (_) {}
    // Return sample playable audio if unavailable
    return 'https://commondatastorage.googleapis.com/codeskulptor-demos/DDR_assets/Kangaroo_MusiQue_-_The_Neverwritten_Role_Playing_Game.mp3';
  }

  // ── Syllable-Synced Lyrics ───────────────────────────────────────
  Future<List<LyricLine>> getLyrics(String trackId, {int durationMs = 0}) async {
    try {
      final res = await _dio.get('/v1/tracks/$trackId/lyrics');
      String raw = '';
      if (res.data is String) {
        raw = res.data as String;
      } else if (res.data is Map) {
        raw = res.data['lyrics']?.toString() ?? res.data['raw']?.toString() ?? '';
      }
      if (raw.isNotEmpty) {
        return LyricParser.parse(raw, songDurationMs: durationMs);
      }
    } catch (_) {}
    return getFallbackLyricsForTrack(trackId);
  }

  // ── Liked Tracks ─────────────────────────────────────────────────
  Future<List<Track>> getLikedTracks() async {
    try {
      final res = await _dio.get('/v1/me/library/tracks');
      if (res.data is Map && res.data['items'] is List) {
        return (res.data['items'] as List)
            .map((e) => Track.fromJson(e['track'] ?? e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return getFallbackPopularTracks().take(3).toList();
  }

  // ── Fallback Rich Mock Data ───────────────────────────────────────
  static List<Track> getFallbackPopularTracks() => [
        const Track(
          id: 'liner_1',
          title: 'Blinding Lights',
          artistName: 'The Weeknd',
          albumName: 'After Hours',
          coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&auto=format&fit=crop&q=80',
          durationMs: 200000,
          playCount: 4210000,
          hasLyrics: true,
          streamUrl: 'https://commondatastorage.googleapis.com/codeskulptor-demos/DDR_assets/Kangaroo_MusiQue_-_The_Neverwritten_Role_Playing_Game.mp3',
        ),
        const Track(
          id: 'liner_2',
          title: 'Starboy',
          artistName: 'The Weeknd ft. Daft Punk',
          albumName: 'Starboy',
          coverUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&auto=format&fit=crop&q=80',
          durationMs: 230000,
          playCount: 3890000,
          hasLyrics: true,
          streamUrl: 'https://commondatastorage.googleapis.com/codeskulptor-demos/DDR_assets/Sevish_-__nbsp_.mp3',
        ),
        const Track(
          id: 'liner_3',
          title: 'Midnight City',
          artistName: 'M83',
          albumName: 'Hurry Up, We\'re Dreaming',
          coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&auto=format&fit=crop&q=80',
          durationMs: 243000,
          playCount: 2950000,
          hasLyrics: true,
          streamUrl: 'https://commondatastorage.googleapis.com/codeskulptor-demos/riceracer_assets/music/menu.ogg',
        ),
        const Track(
          id: 'liner_4',
          title: 'As It Was',
          artistName: 'Harry Styles',
          albumName: 'Harry\'s House',
          coverUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&auto=format&fit=crop&q=80',
          durationMs: 167000,
          playCount: 3120000,
          hasLyrics: true,
          streamUrl: 'https://commondatastorage.googleapis.com/codeskulptor-demos/DDR_assets/Kangaroo_MusiQue_-_The_Neverwritten_Role_Playing_Game.mp3',
        ),
        const Track(
          id: 'liner_5',
          title: 'Levitating',
          artistName: 'Dua Lipa',
          albumName: 'Future Nostalgia',
          coverUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=600&auto=format&fit=crop&q=80',
          durationMs: 203000,
          playCount: 2780000,
          hasLyrics: true,
          streamUrl: 'https://commondatastorage.googleapis.com/codeskulptor-demos/DDR_assets/Sevish_-__nbsp_.mp3',
        ),
      ];

  static List<Playlist> getFallbackDailyMixes() => [
        const Playlist(
          id: 'mix_1',
          name: 'Daily Mix 1',
          description: 'The Weeknd, Daft Punk, Post Malone and more',
          coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&auto=format&fit=crop&q=80',
          trackCount: 25,
        ),
        const Playlist(
          id: 'mix_2',
          name: 'Synthwave Night Ride',
          description: 'Neon retro futuristic beats & melodic synthesizers',
          coverUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=600&auto=format&fit=crop&q=80',
          trackCount: 30,
        ),
        const Playlist(
          id: 'mix_3',
          name: 'Chill Beats & Lo-Fi',
          description: 'Deep focus, calm vibes for late night coding',
          coverUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&auto=format&fit=crop&q=80',
          trackCount: 42,
        ),
      ];

  static List<Artist> getFallbackPopularArtists() => [
        const Artist(
          id: 'art_1',
          name: 'The Weeknd',
          avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=600&auto=format&fit=crop&q=80',
          monthlyListeners: 108500000,
        ),
        const Artist(
          id: 'art_2',
          name: 'Dua Lipa',
          avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=600&auto=format&fit=crop&q=80',
          monthlyListeners: 74200000,
        ),
        const Artist(
          id: 'art_3',
          name: 'Harry Styles',
          avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=600&auto=format&fit=crop&q=80',
          monthlyListeners: 62400000,
        ),
      ];

  static List<LyricLine> getFallbackLyricsForTrack(String trackId) => [
        LyricLine(
          startMs: 1000,
          endMs: 5000,
          text: "Yeah, I've been tryna call",
          words: [
            LyricWord(startMs: 1000, endMs: 1800, text: "Yeah, "),
            LyricWord(startMs: 1800, endMs: 2400, text: "I've "),
            LyricWord(startMs: 2400, endMs: 3100, text: "been "),
            LyricWord(startMs: 3100, endMs: 3900, text: "tryna "),
            LyricWord(startMs: 3900, endMs: 5000, text: "call"),
          ],
        ),
        LyricLine(
          startMs: 5200,
          endMs: 9500,
          text: "I've been on my own for long enough",
          words: [
            LyricWord(startMs: 5200, endMs: 5800, text: "I've "),
            LyricWord(startMs: 5800, endMs: 6400, text: "been "),
            LyricWord(startMs: 6400, endMs: 7000, text: "on "),
            LyricWord(startMs: 7000, endMs: 7600, text: "my "),
            LyricWord(startMs: 7600, endMs: 8200, text: "own "),
            LyricWord(startMs: 8200, endMs: 8800, text: "for "),
            LyricWord(startMs: 8800, endMs: 9200, text: "long "),
            LyricWord(startMs: 9200, endMs: 9500, text: "enough"),
          ],
        ),
        LyricLine(
          startMs: 9800,
          endMs: 14200,
          text: "Maybe you can show me how to love, maybe",
          words: [
            LyricWord(startMs: 9800, endMs: 10400, text: "Maybe "),
            LyricWord(startMs: 10400, endMs: 11000, text: "you "),
            LyricWord(startMs: 11000, endMs: 11600, text: "can "),
            LyricWord(startMs: 11600, endMs: 12200, text: "show "),
            LyricWord(startMs: 12200, endMs: 12800, text: "me "),
            LyricWord(startMs: 12800, endMs: 13400, text: "how "),
            LyricWord(startMs: 13400, endMs: 13800, text: "to "),
            LyricWord(startMs: 13800, endMs: 14200, text: "love, maybe"),
          ],
        ),
        LyricLine(
          startMs: 14500,
          endMs: 19500,
          text: "I'm going through withdrawals",
          words: [
            LyricWord(startMs: 14500, endMs: 15500, text: "I'm "),
            LyricWord(startMs: 15500, endMs: 16800, text: "going "),
            LyricWord(startMs: 16800, endMs: 17800, text: "through "),
            LyricWord(startMs: 17800, endMs: 19500, text: "withdrawals"),
          ],
        ),
        LyricLine(
          startMs: 20000,
          endMs: 25000,
          text: "You don't even have to do too much",
          words: [
            LyricWord(startMs: 20000, endMs: 20800, text: "You "),
            LyricWord(startMs: 20800, endMs: 21600, text: "don't "),
            LyricWord(startMs: 21600, endMs: 22400, text: "even "),
            LyricWord(startMs: 22400, endMs: 23200, text: "have "),
            LyricWord(startMs: 23200, endMs: 23800, text: "to "),
            LyricWord(startMs: 23800, endMs: 24400, text: "do "),
            LyricWord(startMs: 24400, endMs: 25000, text: "too much"),
          ],
        ),
        LyricLine(
          startMs: 25500,
          endMs: 31000,
          text: "You can turn me on with just a touch, baby",
          words: [
            LyricWord(startMs: 25500, endMs: 26200, text: "You "),
            LyricWord(startMs: 26200, endMs: 27000, text: "can "),
            LyricWord(startMs: 27000, endMs: 27800, text: "turn "),
            LyricWord(startMs: 27800, endMs: 28600, text: "me "),
            LyricWord(startMs: 28600, endMs: 29400, text: "on "),
            LyricWord(startMs: 29400, endMs: 30000, text: "with "),
            LyricWord(startMs: 30000, endMs: 30500, text: "just "),
            LyricWord(startMs: 30500, endMs: 31000, text: "a touch"),
          ],
        ),
        LyricLine(
          startMs: 31500,
          endMs: 38000,
          text: "I said, ooh, I'm blinded by the lights",
          words: [
            LyricWord(startMs: 31500, endMs: 32300, text: "I "),
            LyricWord(startMs: 32300, endMs: 33000, text: "said, "),
            LyricWord(startMs: 33000, endMs: 34200, text: "ooh, "),
            LyricWord(startMs: 34200, endMs: 35000, text: "I'm "),
            LyricWord(startMs: 35000, endMs: 35800, text: "blinded "),
            LyricWord(startMs: 35800, endMs: 36600, text: "by "),
            LyricWord(startMs: 36600, endMs: 37200, text: "the "),
            LyricWord(startMs: 37200, endMs: 38000, text: "lights"),
          ],
        ),
        LyricLine(
          startMs: 38500,
          endMs: 45000,
          text: "No, I can't sleep until I feel your touch",
          words: [
            LyricWord(startMs: 38500, endMs: 39200, text: "No, "),
            LyricWord(startMs: 39200, endMs: 39800, text: "I "),
            LyricWord(startMs: 39800, endMs: 40500, text: "can't "),
            LyricWord(startMs: 40500, endMs: 41200, text: "sleep "),
            LyricWord(startMs: 41200, endMs: 42000, text: "until "),
            LyricWord(startMs: 42000, endMs: 42800, text: "I "),
            LyricWord(startMs: 42800, endMs: 43600, text: "feel "),
            LyricWord(startMs: 43600, endMs: 44200, text: "your "),
            LyricWord(startMs: 44200, endMs: 45000, text: "touch"),
          ],
        ),
      ];
}

class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kTokenPrefKey);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
