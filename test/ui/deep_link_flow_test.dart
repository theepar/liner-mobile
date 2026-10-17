import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liner_mobile/core/api/liner_api.dart';
import 'package:liner_mobile/core/utils/deep_link.dart';
import 'package:liner_mobile/providers/player_provider.dart';
import 'package:liner_mobile/services/audio_player_service.dart';
import 'package:liner_mobile/ui/navigation/main_navigation_shell.dart';
import 'package:liner_mobile/ui/screens/player/fullscreen_player.dart';

import '../support/app_harness.dart';
import '../support/fake_api.dart';
import '../support/fake_audio_engine.dart';

const _artistId = 'UCabcdefghijklmnopqrstuv';
const _albumId = 'MPREalbum1234';
const _catalogPlaylistId = 'catalog-123';
const _userPlaylistId = 'c1de5e68-f43a-4a98-9e24-3ec5de58410f';
const _trackId = 'RGdkabupfPI';

Object? _backend(RequestOptions options) {
  switch (options.path) {
    case '/v1/artists/$_artistId':
      return {'id': _artistId, 'name': 'Linked Artist'};
    case '/v1/albums/$_albumId':
      return {
        'id': _albumId,
        'title': 'Linked Album',
        'artists': [
          {'id': _artistId, 'name': 'Linked Artist'},
        ],
      };
    case '/v1/playlists/$_catalogPlaylistId':
      return {'id': _catalogPlaylistId, 'title': 'Catalog Playlist'};
    case '/v1/me/playlists/$_userPlaylistId':
      return {
        'playlist': {'id': _userPlaylistId, 'title': 'My Linked Playlist'},
        'items': <Object?>[],
      };
    case '/v1/tracks/$_trackId':
      return plainTrack(_trackId, title: 'Linked Track');
    case '/v1/tracks/$_trackId/playback':
      return {'streamUrl': 'https://stream.test/$_trackId'};
    case '/v1/tracks/$_trackId/lyrics':
      return sseResponse(const []);
  }
  return const {};
}

FakeAdapter _adapter() => fakeBackend(
  routes: {
    'GET /v1/artists/$_artistId': _backend,
    'GET /v1/albums/$_albumId': _backend,
    'GET /v1/playlists/$_catalogPlaylistId': _backend,
    'GET /v1/me/playlists/$_userPlaylistId': _backend,
    'GET /v1/tracks/$_trackId': _backend,
    'POST /v1/tracks/$_trackId/playback': _backend,
    'GET /v1/tracks/$_trackId/lyrics': _backend,
  },
);

Future<void> _deliver(WidgetTester tester) => tester.pump();

void main() {
  testWidgets('opens a link received before sign-in after authentication', (
    tester,
  ) async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);

    await signedInApp(
      tester,
      _adapter(),
      deepLinks: links,
      beforeSignIn: () async {
        links.emit('liner://artist?id=$_artistId');
        await _deliver(tester);
      },
    );

    expect(find.text('Linked Artist'), findsOneWidget);
  });

  testWidgets('opens a link received while signed in', (tester) async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    await signedInApp(tester, _adapter(), deepLinks: links);

    links.emit('liner://album?id=$_albumId');
    await _deliver(tester);
    await tester.pumpAndSettle();

    expect(find.text('Linked Album'), findsOneWidget);
  });

  testWidgets('opens and starts playback for a track link', (tester) async {
    final links = FakeDeepLinks();
    final adapter = _adapter();
    final engine = FakeAudioEngine();
    final service = AudioPlayerService(
      LinerApi(clientWith(adapter)),
      engine: engine,
    )..autoplaySimilar = false;
    addTearDown(links.dispose);
    addTearDown(service.dispose);

    await signedInApp(
      tester,
      adapter,
      deepLinks: links,
      overrides: [playerServiceProvider.overrideWithValue(service)],
    );

    expect(
      DeepLinks.parse(Uri.parse('liner://track?id=$_trackId')),
      const DeepLinkTarget(DeepLinkType.track, _trackId),
    );
    links.emit('liner://track?id=$_trackId');
    await _deliver(tester);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    for (
      var frame = 0;
      frame < 10 && find.byType(FullscreenPlayer).evaluate().isEmpty;
      frame++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump();

    expect(
      adapter.requests.map((request) => request.path),
      contains('/v1/tracks/$_trackId'),
    );
    expect(find.byType(FullscreenPlayer), findsOneWidget);
    expect(find.text('Linked Track'), findsWidgets);
    expect(
      adapter.requests.map((request) => request.path),
      contains('/v1/tracks/$_trackId/playback'),
    );
    expect(service.currentState.currentTrack?.id, _trackId);
    expect(engine.loadedUrl, 'https://stream.test/$_trackId');
  });

  testWidgets('routes catalog and user playlist links to their API contracts', (
    tester,
  ) async {
    final links = FakeDeepLinks();
    await signedInApp(tester, _adapter(), deepLinks: links);
    addTearDown(links.dispose);

    links.emit('liner://playlist?id=$_catalogPlaylistId');
    await _deliver(tester);
    await tester.pumpAndSettle();
    expect(find.text('Catalog Playlist'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    links.emit('liner://playlist?id=$_userPlaylistId');
    await _deliver(tester);
    await tester.pumpAndSettle();
    expect(find.text('My Linked Playlist'), findsOneWidget);
  });

  testWidgets('ignores an invalid link', (tester) async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    await signedInApp(tester, _adapter(), deepLinks: links);

    links.emit('liner://track?id=not-a-valid-id');
    await _deliver(tester);
    await tester.pumpAndSettle();

    expect(find.byType(MainNavigationShell), findsOneWidget);
    expect(find.text('Linked Track'), findsNothing);
  });
}
