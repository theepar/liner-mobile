import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_api.dart' show jsonResponse;

void main() {
  late List<RequestOptions> log;

  setUp(() => log = []);

  RequestOptions? requestTo(String method, String path) {
    for (final request in log) {
      if (request.method == method && request.path == path) return request;
    }
    return null;
  }

  Future<void> chooseFromAddMenu(WidgetTester tester, String entry) async {
    await tester.tap(find.byTooltip('Add to library'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(entry));
    await tester.pumpAndSettle();
  }

  group('creating playlists', () {
    testWidgets('from scratch sends the name', (tester) async {
      await signedInApp(
        tester,
        fakeBackend(
          log: log,
          routes: {
            'POST /v1/me/playlists': (_) => {'id': 'p9', 'title': 'Road trip'},
          },
        ),
      );
      await openTab(tester, 'Library');

      await chooseFromAddMenu(tester, 'New playlist');
      await tester.enterText(find.byType(TextField).first, 'Road trip');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
      await tester.pumpAndSettle();

      expect(requestTo('POST', '/v1/me/playlists')?.data, {
        'title': 'Road trip',
      });
      expect(find.text('From scratch'), findsNothing);
    });

    testWidgets('a name is required', (tester) async {
      await signedInApp(tester, fakeBackend(log: log));
      await openTab(tester, 'Library');

      await chooseFromAddMenu(tester, 'New playlist');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
      await tester.pump();

      expect(find.text('Enter a playlist name'), findsOneWidget);
      expect(requestTo('POST', '/v1/me/playlists'), isNull);
    });
  });

  group('importing a playlist', () {
    testWidgets('detects the service and starts the import', (tester) async {
      await signedInApp(
        tester,
        fakeBackend(
          log: log,
          routes: {
            'POST /v1/me/playlist-imports': (_) => {
              'id': 'j1',
              'status': 'completed',
              'title': 'Road trip',
              'playlistId': 'p9',
              'result': {'total': 10, 'imported': 8, 'skipped': 2},
            },
          },
        ),
      );
      await openTab(tester, 'Library');

      await chooseFromAddMenu(tester, 'Import a playlist');
      expect(find.text('Import a playlist'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField).first,
        'open.spotify.com/playlist/abc',
      );
      await tester.pump();
      expect(find.text('Detected: Spotify'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Import'));
      await tester.pumpAndSettle();

      expect(requestTo('POST', '/v1/me/playlist-imports')?.data, {
        'url': 'https://open.spotify.com/playlist/abc',
      });
      expect(find.text('Imported 8 of 10 tracks'), findsOneWidget);
      expect(find.text('Open playlist'), findsOneWidget);
    });

    testWidgets('an empty or unsupported link is refused locally', (
      tester,
    ) async {
      await signedInApp(tester, fakeBackend(log: log));
      await openTab(tester, 'Library');
      await chooseFromAddMenu(tester, 'Import a playlist');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Import'));
      await tester.pump();
      expect(find.text('Paste a link first'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'hello');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Import'));
      await tester.pump();
      expect(find.text("That link isn't supported"), findsOneWidget);
      expect(requestTo('POST', '/v1/me/playlist-imports'), isNull);
    });

    testWidgets('shows a rejected link from the server', (tester) async {
      await signedInApp(
        tester,
        fakeBackend(
          log: log,
          routes: {
            'POST /v1/me/playlist-imports': (_) =>
                jsonResponse({'code': 'UNSUPPORTED'}, status: 422),
          },
        ),
      );
      await openTab(tester, 'Library');
      await chooseFromAddMenu(tester, 'Import a playlist');

      await tester.enterText(
        find.byType(TextField).first,
        'https://deezer.com/playlist/1',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Import'));
      await tester.pumpAndSettle();

      expect(find.text("That link isn't supported"), findsOneWidget);
    });

    testWidgets('a job that needs review opens the review screen', (
      tester,
    ) async {
      var status = 'running';
      await signedInApp(
        tester,
        fakeBackend(
          log: log,
          routes: {
            'POST /v1/me/playlist-imports': (_) => {
              'id': 'j1',
              'status': 'queued',
              'title': 'Road trip',
            },
            'GET /v1/me/playlist-imports/j1': (_) => {
              'id': 'j1',
              'status': status,
              'title': 'Road trip',
              if (status == 'completed') 'playlistId': 'p9',
            },
            'GET /v1/me/playlist-imports/j1/review': (_) => {
              'items': [
                {
                  'id': 'r1',
                  'sourceTrack': {
                    'title': 'Original Song',
                    'artists': ['Some Band'],
                    'durationMs': 200000,
                  },
                  'proposedTrack': plainTrack('t5', title: 'Matched Song'),
                  'reason': 'ambiguous_match',
                  'position': 1,
                },
              ],
            },
            'POST /v1/me/playlist-imports/j1/review': (_) => {
              'finalized': true,
            },
          },
        ),
      );
      await openTab(tester, 'Library');
      await chooseFromAddMenu(tester, 'Import a playlist');
      await tester.enterText(
        find.byType(TextField).first,
        'https://open.spotify.com/playlist/abc',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Import'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      status = 'awaiting_decision';
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.text('Review matches'), findsWidgets);
      expect(find.textContaining('Original Song'), findsOneWidget);
      expect(find.text('Matched Song'), findsOneWidget);
      expect(find.text('Multiple matches'), findsOneWidget);

      status = 'completed';
      await tester.tap(find.text('Add 1 match'));
      await tester.pumpAndSettle();

      final submitted = requestTo('POST', '/v1/me/playlist-imports/j1/review')!;
      final body = submitted.data as Map<String, Object?>;
      expect(body['decisions'], [
        {'reviewId': 'r1', 'decision': 'approve'},
      ]);
      expect((body['tracks'] as List<Object?>).length, 1);
      expect(find.text('Original Song'), findsNothing);
    });

    testWidgets('importing SoundCloud likes uses the likes page', (
      tester,
    ) async {
      await signedInApp(
        tester,
        fakeBackend(
          log: log,
          routes: {
            'POST /v1/me/playlist-imports': (_) => {
              'id': 'j2',
              'status': 'completed',
              'playlistId': 'p2',
            },
          },
        ),
      );
      await openTab(tester, 'Library');

      await chooseFromAddMenu(tester, 'Import SoundCloud likes');
      await tester.enterText(find.byType(TextField).first, '@some_user');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Import'));
      await tester.pumpAndSettle();

      expect(requestTo('POST', '/v1/me/playlist-imports')?.data, {
        'url': 'https://soundcloud.com/some_user/likes',
      });
    });
  });

  group('playlist pages', () {
    Map<String, RouteHandler> playlistRoutes() => {
      'GET /v1/me/playlists': (_) => {
        'items': [
          {'id': 'p1', 'title': 'Mine', 'isPublic': false},
        ],
      },
      'GET /v1/me/playlists/p1': (_) => {
        'playlist': {'id': 'p1', 'title': 'Mine', 'description': 'My mix'},
        'items': [
          {'id': 'e1', 'track': plainTrack('t7', title: 'Playlist Song')},
        ],
      },
      'DELETE /v1/me/playlists/p1/items/e1': (_) => null,
    };

    testWidgets('opens a playlist and removes a track', (tester) async {
      await signedInApp(
        tester,
        fakeBackend(log: log, routes: playlistRoutes()),
      );
      await openTab(tester, 'Library');

      await tester.tap(find.text('Mine'));
      await tester.pumpAndSettle();
      expect(find.text('Playlist Song'), findsOneWidget);
      expect(find.text('My mix'), findsOneWidget);

      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Remove from this playlist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from this playlist'));
      await tester.pumpAndSettle();

      expect(requestTo('DELETE', '/v1/me/playlists/p1/items/e1'), isNotNull);
    });

    testWidgets('a playlist can be deleted after confirming', (tester) async {
      await signedInApp(
        tester,
        fakeBackend(
          log: log,
          routes: {
            ...playlistRoutes(),
            'DELETE /v1/me/playlists/p1': (_) => null,
          },
        ),
      );
      await openTab(tester, 'Library');
      await tester.tap(find.text('Mine'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.more_vert_rounded),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete playlist'));
      await tester.pumpAndSettle();
      expect(find.text('Delete playlist?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(requestTo('DELETE', '/v1/me/playlists/p1'), isNotNull);
      expect(find.text('Your Library'), findsOneWidget);
    });
  });

  group('adding songs', () {
    testWidgets('a trending song can be added to a playlist', (tester) async {
      await signedInApp(
        tester,
        fakeBackend(
          log: log,
          routes: {
            'GET /v1/me/playlists': (_) => {
              'items': [
                {'id': 'p1', 'title': 'Mine'},
              ],
            },
            'POST /v1/me/playlists/p1/tracks/t1': (_) => {'id': 'e2'},
          },
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Trending Song'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );

      await tester.tap(find.byTooltip('More options').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to playlist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mine'));
      await tester.pumpAndSettle();

      expect(requestTo('POST', '/v1/me/playlists/p1/tracks/t1'), isNotNull);
      expect(find.text('Added to playlist'), findsOneWidget);
    });
  });

  group('detail pages', () {
    testWidgets('an album found in search opens and can be saved', (
      tester,
    ) async {
      await signedInApp(
        tester,
        fakeBackend(
          log: log,
          routes: {
            'GET /v1/search': (_) => {
              'items': [
                {
                  'type': 'album',
                  'id': 'alb1',
                  'title': 'Night Album',
                  'year': 2024,
                  'artists': [
                    {'id': 'ar1', 'name': 'Artist One'},
                  ],
                },
              ],
            },
            'GET /v1/albums/alb1': (_) => {
              'id': 'alb1',
              'title': 'Night Album',
              'year': 2024,
              'artists': [
                {'id': 'ar1', 'name': 'Artist One'},
              ],
              'tracks': [plainTrack('t3', title: 'Album Track')],
            },
            'PUT /v1/me/library/albums/alb1': (_) => null,
          },
        ),
      );
      await openTab(tester, 'Search');
      await tester.enterText(find.byType(TextField), 'night');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Night Album'));
      await tester.pumpAndSettle();

      expect(find.text('Album Track'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Save'));
      await tester.pumpAndSettle();
      expect(requestTo('PUT', '/v1/me/library/albums/alb1'), isNotNull);
    });

    testWidgets('an artist page lists popular tracks and releases', (
      tester,
    ) async {
      await signedInApp(
        tester,
        fakeBackend(
          log: log,
          routes: {
            'GET /v1/search': (_) => {
              'items': [
                {'type': 'artist', 'id': 'ar1', 'name': 'Artist One'},
              ],
            },
            'GET /v1/artists/ar1': (_) => {
              'id': 'ar1',
              'name': 'Artist One',
              'verified': true,
              'monthlyListeners': '12.3M',
              'tracks': [plainTrack('t4', title: 'Top Hit')],
              'albums': [
                {'id': 'alb1', 'title': 'First Album', 'year': 2020},
              ],
            },
          },
        ),
      );
      await openTab(tester, 'Search');
      await tester.enterText(find.byType(TextField), 'artist');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Artist One'));
      await tester.pumpAndSettle();

      expect(find.text('12.3M monthly listeners'), findsOneWidget);
      expect(find.text('Top Hit'), findsOneWidget);
      expect(find.text('First Album'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    });
  });
}
