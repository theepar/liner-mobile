import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liner_mobile/core/api/api_client.dart';
import 'package:liner_mobile/core/api/liner_api.dart';
import 'package:liner_mobile/core/api/request_signer.dart';
import 'package:liner_mobile/core/models/lyric.dart';
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

    test('maps the API error code to a user-facing message', () async {
      Future<AuthException> failWith(int? status, {String? code}) async {
        final client = clientWith(
          FakeAdapter((options) {
            if (status == null) {
              throw DioException.connectionError(
                requestOptions: options,
                reason: 'offline',
              );
            }
            return jsonResponse({
              'message': 'internal detail',
              'code': ?code,
            }, status: status);
          }),
        );
        try {
          await client.login('a@b.c', 'x');
        } on AuthException catch (error) {
          return error;
        }
        fail('expected AuthException');
      }

      expect(
        (await failWith(401, code: 'INVALID_CREDENTIALS')).message,
        'Email or password is incorrect.',
      );
      expect(
        (await failWith(409, code: 'EMAIL_ALREADY_USED')).message,
        'This email is already in use.',
      );
      expect(
        (await failWith(409, code: 'USERNAME_TAKEN')).message,
        'This username is already taken. Please choose another.',
      );
      expect(
        (await failWith(400, code: 'INVALID_USERNAME')).message,
        contains('3-30'),
      );
      expect(
        (await failWith(400, code: 'INVALID_INPUT')).message,
        'Please check the details you entered.',
      );
      expect(
        (await failWith(500)).message,
        'The server is having problems. Try again later.',
      );
      expect(
        (await failWith(null)).message,
        'Cannot reach the server. Check your connection.',
      );
    });

    test(
      'a bare 401 is reported as a rejected client, not a bad password',
      () async {
        final client = clientWith(
          FakeAdapter((_) => jsonResponse({}, status: 401)),
        );

        final error = await client
            .register(
              email: 'me@example.com',
              password: 'password123',
              username: 'me',
              displayName: 'Me',
            )
            .then<AuthException?>((_) => null)
            .onError<AuthException>((error, _) => error);

        expect(error!.message, contains('rejected this app'));
        expect(error.message, isNot(contains('password')));
      },
    );

    test('normalizes and sends exactly the registration fields', () async {
      final adapter = FakeAdapter((_) => jsonResponse(authPayload()));
      final client = clientWith(adapter);

      await client.register(
        email: '  Me@Example.COM ',
        password: 'password123',
        username: ' MyName_1 ',
        displayName: '  My Name  ',
      );

      expect(adapter.requests.single.path, '/v1/auth/register');
      expect(adapter.requests.single.data, {
        'email': 'me@example.com',
        'password': 'password123',
        'username': 'myname_1',
        'displayName': 'My Name',
      });
    });

    test('every request carries a request id and client metadata', () async {
      final adapter = FakeAdapter((_) => jsonResponse({'items': <Object?>[]}));
      final client = clientWith(adapter);

      await client.get('/v1/me/playlists');
      await client.get('/v1/me/playlists');

      final ids = adapter.requests
          .map((r) => r.headers['x-request-id'])
          .toSet();
      expect(ids, hasLength(2));
      expect(
        ids.first,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    });

    test('a signer receives the exact body and server-adjusted time', () async {
      final signer = _RecordingSigner();
      final adapter = FakeAdapter(
        (options) => ResponseBody.fromString(
          '{}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'x-liner-server-time': ['4102444800'],
          },
        ),
      );
      final client = clientWith(adapter)..signer = signer;

      await client.get('/v1/explore/popular');
      await client.post('/v1/me/playlists', body: {'title': 'Mix'});

      final post = signer.calls.last;
      expect(post.method, 'POST');
      expect(post.path, '/v1/me/playlists');
      expect(post.body, '{"title":"Mix"}');
      expect(adapter.requests.last.data, '{"title":"Mix"}');
      expect(adapter.requests.last.headers['x-liner-signature'], 'sig');
      expect(post.timestamp, greaterThanOrEqualTo(4102444800));
      expect(signer.calls.first.body, isNull);
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

  group('checkConnection', () {
    ApiClient clientAnswering(FakeAdapter adapter) =>
        ApiClient.withDio(Dio()..httpClientAdapter = adapter);

    test('reports the status and latency of the active server', () async {
      final adapter = FakeAdapter((_) => jsonResponse({'status': 'ok'}));

      final report = await clientAnswering(adapter).checkConnection();

      expect(report.isReachable, isTrue);
      expect(report.latency, isNotNull);
      expect(adapter.requests.single.uri.path, '/health');
      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('a server error is not reachable but has no failure reason', () async {
      final adapter = FakeAdapter((_) => jsonResponse({}, status: 503));

      final report = await clientAnswering(adapter).checkConnection();

      expect(report.isReachable, isFalse);
      expect(report.statusCode, 503);
      expect(report.failure, isNull);
    });

    test('says why it could not connect, without switching server', () async {
      final adapter = FakeAdapter((options) {
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'unreachable',
        );
      });
      final client = clientAnswering(adapter);
      final before = client.baseUrl;

      final report = await client.checkConnection();

      expect(report.isReachable, isFalse);
      expect(report.failure, 'Could not connect');
      expect(client.baseUrl, before);
      expect(adapter.requests, hasLength(1));
    });

    test('a timeout is reported as such', () async {
      final adapter = FakeAdapter((options) {
        throw DioException.connectionTimeout(
          timeout: const Duration(seconds: 4),
          requestOptions: options,
        );
      });

      final report = await clientAnswering(adapter).checkConnection();

      expect(report.failure, 'Timed out');
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

  group('LinerApi.streamLyrics', () {
    final provider = lyricsProviderEvent;

    test('yields every provider that found lyrics, in arrival order', () async {
      final adapter = FakeAdapter(
        (_) => sseResponse([
          {'type': 'metadata'},
          provider('a', 'lrc', '[00:01.00]line sync', 'line_level', 90),
          provider('b', 'ttml', '<tt/>', 'syllable_level', 99),
          provider('c', 'plain', 'no timing', 'plain', 100),
          {'type': 'done', 'cached': false},
        ]),
      );

      final candidates = await LinerApi(
        clientWith(adapter),
      ).streamLyrics('t1').toList();

      expect(candidates.map((c) => c.provider), ['a', 'b', 'c']);
      expect(candidates[1].syncLevel, LyricsSyncLevel.syllable);
      expect(candidates[1].format, 'ttml');
      expect(candidates[0].quality, 90);
      expect(adapter.requests.single.headers['Accept'], 'text/event-stream');
    });

    test('stops reading at the done event', () async {
      final adapter = FakeAdapter(
        (_) => sseResponse([
          provider('a', 'lrc', '[00:01.00]first', 'line_level', 10),
          {'type': 'done', 'cached': true},
          provider('late', 'lrc', '[00:01.00]ignored', 'line_level', 99),
        ]),
      );

      final candidates = await LinerApi(
        clientWith(adapter),
      ).streamLyrics('t1').toList();

      expect(candidates.map((c) => c.provider), ['a']);
    });

    test('yields nothing when no provider found lyrics', () async {
      final adapter = FakeAdapter(
        (_) => sseResponse([
          {'type': 'provider', 'provider': 'a', 'status': 'not_found'},
          {'type': 'done', 'cached': false, 'status': 'not_found'},
        ]),
      );

      expect(
        await LinerApi(clientWith(adapter)).streamLyrics('t1').toList(),
        isEmpty,
      );
    });
  });
}

class _SignCall {
  _SignCall(this.method, this.path, this.timestamp, this.body);

  final String method;
  final String path;
  final int timestamp;
  final String? body;
}

class _RecordingSigner implements RequestSigner {
  final calls = <_SignCall>[];

  @override
  Future<Map<String, String>> sign({
    required String method,
    required String path,
    required int timestamp,
    String? body,
  }) async {
    calls.add(_SignCall(method, path, timestamp, body));
    return {
      'x-liner-signature': 'sig',
      'x-liner-timestamp': '$timestamp',
      'x-liner-nonce': 'nonce',
    };
  }
}
