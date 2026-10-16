import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liner_mobile/core/api/liner_api.dart';
import 'package:liner_mobile/core/models/playback_event.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_api.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test('posts a playback event with the contract fields', () async {
    final adapter = FakeAdapter((_) => jsonResponse(null, status: 204));
    const event = PlaybackEvent(
      playbackSessionId: 'ps-1',
      listeningSessionId: 'ls-1',
      trackId: 't1',
      playedDurationMs: 42000,
      trackDurationMs: 200000,
      completionRate: 0.21,
      completed: false,
      skipped: false,
      loopCount: 0,
      hasSeekBackward: true,
      context: PlaybackContext.playlist('p1'),
    );

    await LinerApi(clientWith(adapter)).recordPlaybackEvent(event);

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/v1/me/playback/events');
    expect(request.data, event.toJson());
    expect((request.data as Map<String, Object?>)['context'], {
      'type': 'playlist',
      'id': 'p1',
    });
  });

  test('sends user correlation headers once signed in', () async {
    final adapter = FakeAdapter((options) {
      return options.path == '/v1/auth/login'
          ? jsonResponse(authPayload())
          : jsonResponse({'items': <Object?>[]});
    });
    final client = clientWith(adapter);

    await client.login('me@example.com', 'password123');
    await client.get('/v1/me/playlists');

    expect(adapter.requests.first.headers.containsKey('x-user-id'), isFalse);
    expect(adapter.requests.last.headers['x-user-id'], 'u1');
    expect(adapter.requests.last.headers['x-user-name'], 'me');
  });
}
