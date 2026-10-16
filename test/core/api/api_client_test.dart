import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liner_mobile/core/api/api_client.dart';
import 'package:liner_mobile/core/api/liner_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_api.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  group('authentication', () {
    test('login stores the session and attaches the bearer token', () async {
      final adapter = FakeAdapter((options) {
        if (options.path == '/v1/auth/login') {
          return jsonResponse(authPayload());
        }
        return jsonResponse({'items': <Object?>[]});
      });
      final client = clientWith(adapter);

      final user = await client.login('me@example.com', 'secret');
      await client.get('/v1/me/playlists');

      expect(user.username, 'me');
      expect(client.currentUser, user);
      expect(adapter.requests.first.data, {
        'email': 'me@example.com',
        'password': 'secret',
      });
      expectAuthorization(adapter.requests.first, null);
      expectAuthorization(adapter.requests.last, 'Bearer access-1');
    });

    test('maps auth failures to user-facing messages', () async {
      Future<AuthException> failWith(int? status) async {
        final client = clientWith(
          FakeAdapter((options) {
            if (status == null) {
              throw DioException.connectionError(
                requestOptions: options,
                reason: 'offline',
              );
            }
            return jsonResponse({'message': 'internal detail'}, status: status);
          }),
        );
        try {
          await client.login('a@b.c', 'x');
        } on AuthException catch (error) {
          return error;
        }
        fail('expected AuthException');
      }

      expect((await failWith(401)).message, 'Incorrect email or password.');
      expect(
        (await failWith(409)).message,
        'That email or username is already taken.',
      );
      expect((await failWith(500)).message, isNot(contains('internal detail')));
    });

    test(
      'a rejected token is refreshed once and the request retried',
      () async {
        var protectedCalls = 0;
        final adapter = FakeAdapter((options) {
          switch (options.path) {
            case '/v1/auth/login':
              return jsonResponse(authPayload());
            case '/v1/auth/refresh':
              expect(options.data, {'refreshToken': 'refresh-1'});
              return jsonResponse(
                authPayload(access: 'access-2', refresh: 'refresh-2'),
              );
            default:
              protectedCalls++;
              final isStale =
                  options.headers['Authorization'] == 'Bearer access-1';
              return isStale
                  ? jsonResponse({'message': 'expired'}, status: 401)
                  : jsonResponse({'items': <Object?>[]});
          }
        });
        final client = clientWith(adapter);
        await client.login('me@example.com', 'secret');

        await client.get('/v1/me/playlists');

        expect(protectedCalls, 2);
        expectAuthorization(adapter.requests.last, 'Bearer access-2');
      },
    );

    test('a revoked refresh token signs the user out', () async {
      final adapter = FakeAdapter((options) {
        if (options.path == '/v1/auth/login') {
          return jsonResponse(authPayload());
        }
        return jsonResponse({'message': 'no'}, status: 401);
      });
      final client = clientWith(adapter);
      await client.login('me@example.com', 'secret');
      final signedOut = client.userChanges.firstWhere((user) => user == null);

      await expectLater(
        client.get('/v1/me/playlists'),
        throwsA(isA<ApiException>()),
      );

      expect(await signedOut, isNull);
      expect(client.currentUser, isNull);
    });
  });

  group('failover', () {
    test('retries on the edge relay when the primary is unreachable', () async {
      final adapter = FakeAdapter((options) {
        if (options.baseUrl.startsWith('https://api.tryliner.fun')) {
          throw DioException.connectionError(
            requestOptions: options,
            reason: 'unreachable',
          );
        }
        return jsonResponse({'items': <Object?>[]});
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://api.tryliner.fun'))
        ..httpClientAdapter = adapter;
      final client = ApiClient.withDio(dio);

      await client.get('/v1/explore/popular');

      expect(adapter.requests.last.baseUrl, 'http://edge.tryliner.fun:10518');
      expect(client.baseUrl, 'http://edge.tryliner.fun:10518');
      expect(client.isUsingFallback, isTrue);
    });
  });

  group('LinerApi', () {
    test('reads popular tracks from /v1/explore/popular', () async {
      final adapter = FakeAdapter(
        (options) => jsonResponse({
          'items': [
            {'rank': 1, 'track': trackJson('t1'), 'playCount': 10},
            {'rank': 2, 'track': trackJson('t2'), 'playCount': 5},
          ],
        }),
      );

      final tracks = await LinerApi(clientWith(adapter)).getPopularTracks();

      expect(tracks.map((t) => t.id), ['t1', 't2']);
      expect(adapter.requests.single.path, '/v1/explore/popular');
      expect(adapter.requests.single.queryParameters, {
        'window': '7d',
        'limit': 20,
      });
    });

    test('surfaces API failures instead of substituting data', () async {
      final api = LinerApi(
        clientWith(FakeAdapter((_) => jsonResponse({}, status: 500))),
      );

      await expectLater(api.getPopularTracks(), throwsA(isA<ApiException>()));
    });

    test(
      'requests the proxy transport and resolves a relative stream URL',
      () async {
        final adapter = FakeAdapter(
          (options) => jsonResponse({'streamUrl': '/v1/playback/pb_1/media'}),
        );

        final url = await LinerApi(clientWith(adapter)).getStreamUrl('t1');

        expect(adapter.requests.single.data, {'transport': 'proxy'});
        expect(url, endsWith('/v1/playback/pb_1/media'));
        expect(Uri.parse(url).hasAuthority, isTrue);
      },
    );

    test('fails when playback returns no stream', () async {
      final api = LinerApi(
        clientWith(
          FakeAdapter((_) => jsonResponse({'transport': 'direct_innertube'})),
        ),
      );

      await expectLater(
        api.getStreamUrl('t1'),
        throwsA(isA<StreamUnavailableException>()),
      );
    });

    test('likes and unlikes through the library endpoint', () async {
      final adapter = FakeAdapter((_) => jsonResponse(null, status: 204));
      final api = LinerApi(clientWith(adapter));

      await api.likeTrack('t 1');
      await api.unlikeTrack('t 1');

      expect(adapter.requests.map((r) => r.method), ['PUT', 'DELETE']);
      expect(adapter.requests.first.path, '/v1/me/library/tracks/t%201');
    });

    test('follows liked-track pagination cursors', () async {
      final adapter = FakeAdapter((options) {
        final cursor = options.queryParameters['cursor'];
        return jsonResponse(
          cursor == null
              ? {
                  'items': [
                    {'track': trackJson('t1'), 'likedAt': 'x'},
                  ],
                  'nextCursor': 'next',
                }
              : {
                  'items': [
                    {'track': trackJson('t2'), 'likedAt': 'x'},
                  ],
                  'nextCursor': null,
                },
        );
      });

      final tracks = await LinerApi(clientWith(adapter)).getLikedTracks();

      expect(tracks.map((t) => t.id), ['t1', 't2']);
    });

    test('dedupes the recently played history', () async {
      final adapter = FakeAdapter(
        (_) => jsonResponse({
          'items': [
            {'track': trackJson('t1')},
            {'track': trackJson('t2')},
            {'track': trackJson('t1')},
          ],
        }),
      );

      final tracks = await LinerApi(clientWith(adapter)).getRecentlyPlayed();

      expect(tracks.map((t) => t.id), ['t1', 't2']);
    });
  });

  group('LinerApi.getLyrics', () {
    Map<String, Object?> provider(
      String name,
      String format,
      String content,
      String syncLevel,
      num quality,
    ) => {
      'type': 'provider',
      'provider': name,
      'status': 'found',
      'syncLevel': syncLevel,
      'candidate': {
        'provider': name,
        'lyrics': {'format': format, 'content': content},
        'syncLevel': syncLevel,
        'quality': {'total': quality},
      },
    };

    test('prefers the most granular supported candidate', () async {
      final adapter = FakeAdapter(
        (_) => sseResponse([
          {'type': 'metadata'},
          provider('a', 'lrc', '[00:01.00]line sync', 'line_level', 90),
          provider('b', 'ttml', '<tt/>', 'syllable_level', 99),
          provider('c', 'plain', 'no timing', 'plain', 100),
          provider(
            'd',
            'richsync',
            '[{"ts":1.0,"te":3.0,"l":[{"c":"word","o":0.0}]}]',
            'word_level',
            50,
          ),
          {'type': 'done', 'cached': false},
        ]),
      );

      final lyrics = await LinerApi(clientWith(adapter)).getLyrics('t1');

      expect(lyrics.single.text, 'word');
      expect(adapter.requests.single.headers['Accept'], 'text/event-stream');
    });

    test('breaks ties on quality', () async {
      final adapter = FakeAdapter(
        (_) => sseResponse([
          provider('a', 'lrc', '[00:01.00]worse', 'line_level', 10),
          provider('b', 'lrc', '[00:01.00]better', 'line_level', 80),
          {'type': 'done', 'cached': true},
        ]),
      );

      final lyrics = await LinerApi(clientWith(adapter)).getLyrics('t1');

      expect(lyrics.single.text, 'better');
    });

    test('returns no lyrics when nothing usable was found', () async {
      final adapter = FakeAdapter(
        (_) => sseResponse([
          {'type': 'provider', 'provider': 'a', 'status': 'not_found'},
          {'type': 'done', 'cached': false, 'status': 'not_found'},
        ]),
      );

      expect(await LinerApi(clientWith(adapter)).getLyrics('t1'), isEmpty);
    });
  });
}
