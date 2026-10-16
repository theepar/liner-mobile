import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liner_mobile/core/api/liner_api.dart';
import 'package:liner_mobile/core/models/collection_type.dart';
import 'package:liner_mobile/core/models/playlist_import.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_api.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  LinerApi apiWith(FakeAdapter adapter) => LinerApi(clientWith(adapter));

  group('playlists', () {
    test('creates a playlist with an optional description', () async {
      final adapter = FakeAdapter(
        (_) => jsonResponse({'id': 'p1', 'title': 'Road trip'}),
      );

      final playlist = await apiWith(
        adapter,
      ).createPlaylist('Road trip', description: 'Long drives');

      expect(playlist.id, 'p1');
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/v1/me/playlists');
      expect(request.data, {
        'title': 'Road trip',
        'description': 'Long drives',
      });
    });

    test('omits an absent description', () async {
      final adapter = FakeAdapter(
        (_) => jsonResponse({'id': 'p1', 'title': 'A'}),
      );

      await apiWith(adapter).createPlaylist('A');

      expect(adapter.requests.single.data, {'title': 'A'});
    });

    test(
      'adds, removes, renames and deletes with the desktop endpoints',
      () async {
        final adapter = FakeAdapter((_) => jsonResponse(null, status: 204));
        final api = apiWith(adapter);

        await api.addTrackToPlaylist('p 1', 't1');
        await api.removePlaylistItem('p1', 'item-9');
        await api.updatePlaylist('p1', title: 'New name');
        await api.deletePlaylist('p1');

        expect(adapter.requests.map((r) => '${r.method} ${r.path}'), [
          'POST /v1/me/playlists/p%201/tracks/t1',
          'DELETE /v1/me/playlists/p1/items/item-9',
          'PATCH /v1/me/playlists/p1',
          'DELETE /v1/me/playlists/p1',
        ]);
        expect(adapter.requests[2].data, {'title': 'New name'});
      },
    );

    test('reads a playlist with its entry ids', () async {
      final adapter = FakeAdapter(
        (_) => jsonResponse({
          'playlist': {'id': 'p1', 'title': 'Mine'},
          'items': [
            {'id': 'e1', 'track': trackJson('t1')},
          ],
        }),
      );

      final details = await apiWith(adapter).getUserPlaylist('p1');

      expect(details.items.single.id, 'e1');
      expect(details.tracks.single.id, 't1');
    });
  });

  group('library collections', () {
    test('reads saved entries from the key matching the collection', () async {
      final adapter = FakeAdapter((options) {
        return jsonResponse(switch (options.path) {
          '/v1/me/library/albums' => {
            'items': [
              {
                'album': {'id': 'alb1', 'title': 'Album'},
                'savedAt': 'x',
              },
            ],
          },
          '/v1/me/library/playlists' => {
            'items': [
              {
                'playlist': {'id': 'pl1', 'title': 'Saved', 'author': 'Liner'},
              },
            ],
          },
          _ => {
            'items': [
              {
                'artist': {'id': 'ar1', 'name': 'Artist'},
              },
            ],
          },
        });
      });
      final api = apiWith(adapter);

      expect((await api.getSavedAlbums()).single.title, 'Album');
      expect((await api.getSavedPlaylists()).single.author, 'Liner');
      expect((await api.getFollowedArtists()).single.name, 'Artist');
    });

    test('saves and removes through PUT and DELETE', () async {
      final adapter = FakeAdapter((_) => jsonResponse(null, status: 204));
      final api = apiWith(adapter);

      await api.saveCollection(CollectionType.albums, 'alb 1');
      await api.removeCollection(CollectionType.artists, 'ar1');

      expect(adapter.requests.map((r) => '${r.method} ${r.path}'), [
        'PUT /v1/me/library/albums/alb%201',
        'DELETE /v1/me/library/artists/ar1',
      ]);
    });
  });

  group('details', () {
    test('loads artist, album, catalog playlist and track by id', () async {
      final adapter = FakeAdapter((options) {
        return jsonResponse(switch (options.path) {
          '/v1/artists/UC1' => {
            'id': 'UC1',
            'name': 'Artist',
            'tracks': [trackJson('t1')],
          },
          '/v1/albums/alb1' => {
            'id': 'alb1',
            'title': 'Album',
            'tracks': [trackJson('t2')],
          },
          '/v1/playlists/pl1' => {
            'id': 'pl1',
            'title': 'Playlist',
            'tracks': [trackJson('t3')],
          },
          _ => trackJson('t9'),
        });
      });
      final api = apiWith(adapter);

      expect((await api.getArtist('UC1')).tracks.single.id, 't1');
      expect((await api.getAlbum('alb1')).tracks.single.id, 't2');
      expect((await api.getCatalogPlaylist('pl1')).tracks.single.id, 't3');
      expect((await api.getTrack('t9')).id, 't9');
    });
  });

  group('radio', () {
    test('a fresh station is a GET with the wave id', () async {
      final adapter = FakeAdapter(
        (_) => jsonResponse({
          'items': [trackJson('r1')],
        }),
      );

      final tracks = await apiWith(adapter).getRadio('seed', waveId: 'wave-1');

      expect(tracks.single.id, 'r1');
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/v1/tracks/seed/radio');
      expect(request.queryParameters, {'k': 20, 'wave_id': 'wave-1'});
    });

    test('with history it is a POST so the server can avoid repeats', () async {
      final adapter = FakeAdapter((_) => jsonResponse({'items': <Object?>[]}));

      await apiWith(adapter).getRadio('seed', history: ['a', 'b'], waveId: 'w');

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.data, {
        'history': ['a', 'b'],
        'k': 20,
        'wave_id': 'w',
      });
    });
  });

  group('playlist import', () {
    test('creates a job from a link', () async {
      final adapter = FakeAdapter(
        (_) => jsonResponse({
          'id': 'j1',
          'status': 'queued',
          'importToken': 'tok',
        }),
      );

      final job = await apiWith(
        adapter,
      ).createPlaylistImport('https://open.spotify.com/playlist/x');

      expect(job.status, ImportStatus.queued);
      expect(job.importToken, 'tok');
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/v1/me/playlist-imports');
      expect(request.data, {'url': 'https://open.spotify.com/playlist/x'});
    });

    test(
      'submits review decisions together with the approved tracks',
      () async {
        final adapter = FakeAdapter((_) => jsonResponse({'finalized': true}));

        final finalized = await apiWith(adapter).decidePlaylistImportReview(
          'j1',
          decisions: const [
            ImportReviewDecision(reviewId: 'r1', approve: true),
          ],
          approvedTracks: [trackJson('t1')],
          title: 'Road trip',
        );

        expect(finalized, isTrue);
        final request = adapter.requests.single;
        expect(request.path, '/v1/me/playlist-imports/j1/review');
        expect(request.data, {
          'decisions': [
            {'reviewId': 'r1', 'decision': 'approve'},
          ],
          'tracks': [trackJson('t1')],
          'title': 'Road trip',
        });
      },
    );

    test('skipping keeps only the automatic matches', () async {
      final adapter = FakeAdapter((_) => jsonResponse({'finalized': false}));

      final finalized = await apiWith(adapter).skipPlaylistImportReview('j1');

      expect(finalized, isFalse);
      expect(adapter.requests.single.data, {'action': 'skip'});
    });
  });
}
