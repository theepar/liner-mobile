import 'package:flutter_test/flutter_test.dart';
import 'package:liner_mobile/core/models/artist.dart';
import 'package:liner_mobile/core/models/liner_user.dart';
import 'package:liner_mobile/core/models/player_state.dart';
import 'package:liner_mobile/core/models/playlist.dart';
import 'package:liner_mobile/core/models/search_results.dart';
import 'package:liner_mobile/core/models/track.dart';
import 'package:liner_mobile/core/utils/formatters.dart';

void main() {
  group('Track.fromJson', () {
    test('maps the API contract', () {
      final track = Track.fromJson({
        'id': 'abc',
        'title': 'Blinding Lights',
        'artists': [
          {'id': 'a1', 'name': 'The Weeknd'},
          {'id': 'a2', 'name': 'Daft Punk'},
        ],
        'album': {'id': 'al1', 'title': 'After Hours'},
        'durationMs': 200000,
        'cover': {
          'url': 'https://img/a.jpg',
          'fallbackUrl': 'https://fb/a.jpg',
        },
        'explicit': true,
      });

      expect(track.id, 'abc');
      expect(track.artistName, 'The Weeknd, Daft Punk');
      expect(track.artistId, 'a1');
      expect(track.albumName, 'After Hours');
      expect(track.coverUrl, 'https://img/a.jpg');
      expect(track.coverFallbackUrl, 'https://fb/a.jpg');
      expect(track.explicit, isTrue);
      expect(track.durationFormatted, '3:20');
      expect(track.shareUrl, 'https://link.tryliner.fun/track?id=abc');
      expect(track.deepLink, 'liner://track?id=abc');
    });

    test('tolerates missing and malformed fields without fabricating data', () {
      final track = Track.fromJson({
        'id': 42,
        'artists': 'not a list',
        'durationMs': 'oops',
      });

      expect(track.id, '42');
      expect(track.title, 'Untitled Track');
      expect(track.artistName, 'Unknown Artist');
      expect(track.coverUrl, isEmpty);
      expect(track.durationMs, 0);
    });

    test('encodes ids in share links', () {
      const track = Track(id: 'a b&c', title: 't');
      expect(track.shareUrl, endsWith('?id=a+b%26c'));
    });
  });

  group('SearchResults.fromJson', () {
    test('splits the heterogeneous items list by type', () {
      final results = SearchResults.fromJson({
        'items': [
          {'type': 'track', 'id': 't1', 'title': 'Song'},
          {
            'type': 'artist',
            'id': 'ar1',
            'name': 'Artist',
            'cover': {'url': 'https://img/ar1.jpg'},
          },
          {'type': 'playlist', 'id': 'p1', 'title': 'Mix', 'author': 'Liner'},
          {'type': 'album', 'id': 'alb1', 'title': 'Skipped'},
          'garbage',
        ],
      });

      expect(results.tracks.single.id, 't1');
      expect(results.artists.single.avatarUrl, 'https://img/ar1.jpg');
      expect(results.playlists.single.author, 'Liner');
      expect(results.isEmpty, isFalse);
    });

    test('is empty for an empty or invalid payload', () {
      expect(SearchResults.fromJson({'items': <Object?>[]}).isEmpty, isTrue);
      expect(SearchResults.fromJson({}).isEmpty, isTrue);
    });
  });

  group('Playlist.fromJson', () {
    test('parses a daily mix with embedded tracks', () {
      final mix = Playlist.fromJson({
        'id': 'mix1',
        'title': 'Daily Mix 1',
        'description': 'Chill',
        'trackCount': 2,
        'cover': {'url': 'https://img/m.jpg'},
        'tracks': [
          {'id': 't1', 'title': 'A'},
          {'id': 't2', 'title': 'B'},
        ],
      });

      expect(mix.title, 'Daily Mix 1');
      expect(mix.trackCount, 2);
      expect(mix.tracks.map((t) => t.id), ['t1', 't2']);
    });

    test('leaves fields a user playlist does not provide empty', () {
      final playlist = Playlist.fromJson({'id': 'p', 'title': 'Mine'});

      expect(playlist.coverUrl, isEmpty);
      expect(playlist.trackCount, isNull);
      expect(playlist.tracks, isEmpty);
    });
  });

  group('LinerUser', () {
    test('compares by value', () {
      final a = LinerUser.fromJson({'id': '1', 'email': 'a@b.c'});
      final b = LinerUser.fromJson({'id': '1', 'email': 'a@b.c'});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('falls back from display name to username to email', () {
      expect(const LinerUser(id: '1', displayName: 'Ada').name, 'Ada');
      expect(const LinerUser(id: '1', username: 'ada').name, 'ada');
      expect(const LinerUser(id: '1', email: 'a@b.c').name, 'a@b.c');
    });
  });

  test('Artist reads its avatar from cover.url', () {
    final artist = Artist.fromJson({
      'id': 'a',
      'name': 'N',
      'cover': {'url': 'https://img/a.jpg'},
    });
    expect(artist.avatarUrl, 'https://img/a.jpg');
  });

  group('PlayerStateData', () {
    test('progress is clamped and safe for zero duration', () {
      expect(const PlayerStateData().progress, 0);
      expect(
        const PlayerStateData(
          position: Duration(seconds: 30),
          duration: Duration(seconds: 120),
        ).progress,
        0.25,
      );
      expect(
        const PlayerStateData(
          position: Duration(seconds: 200),
          duration: Duration(seconds: 120),
        ).progress,
        1,
      );
    });
  });

  group('formatters', () {
    test('formatDuration pads seconds', () {
      expect(formatDuration(const Duration(seconds: 65)), '1:05');
      expect(formatDuration(Duration.zero), '0:00');
    });

    test('formatCompactCount abbreviates thousands and millions', () {
      expect(formatCompactCount(999), '999');
      expect(formatCompactCount(1500), '1.5K');
      expect(formatCompactCount(4210000), '4.2M');
    });
  });
}
