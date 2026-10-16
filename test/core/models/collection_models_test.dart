import 'package:flutter_test/flutter_test.dart';
import 'package:liner_mobile/core/models/album.dart';
import 'package:liner_mobile/core/models/artist_details.dart';
import 'package:liner_mobile/core/models/playlist.dart';
import 'package:liner_mobile/core/models/playlist_import.dart';
import 'package:liner_mobile/core/models/search_results.dart';
import 'package:liner_mobile/core/utils/import_source.dart';

Map<String, Object?> _track(String id, {Map<String, Object?>? cover}) => {
  'id': id,
  'title': 'Track $id',
  'artists': [
    {'id': 'a1', 'name': 'Artist'},
  ],
  'cover': ?cover,
};

void main() {
  group('Album', () {
    test('tracks inherit the album cover and album details', () {
      final album = Album.fromJson({
        'id': 'alb1',
        'title': 'Night Drive',
        'year': 2024,
        'artists': [
          {'id': 'a1', 'name': 'Artist'},
        ],
        'cover': {
          'url': 'https://img/alb.jpg',
          'fallbackUrl': 'https://fb/alb.jpg',
        },
        'tracks': [
          _track('t1'),
          _track('t2', cover: {'url': 'https://img/own.jpg'}),
        ],
      });

      expect(album.artistName, 'Artist');
      expect(album.tracks[0].coverUrl, 'https://img/alb.jpg');
      expect(album.tracks[0].coverFallbackUrl, 'https://fb/alb.jpg');
      expect(album.tracks[0].albumId, 'alb1');
      expect(album.tracks[0].albumName, 'Night Drive');
      expect(album.tracks[1].coverUrl, 'https://img/own.jpg');
      expect(album.shareUrl, 'https://link.tryliner.fun/album?id=alb1');
    });
  });

  group('ArtistDetails', () {
    test('parses the profile, popular tracks and releases', () {
      final artist = ArtistDetails.fromJson({
        'id': 'UC1',
        'name': 'Artist',
        'bio': 'Bio text',
        'verified': true,
        'monthlyListeners': '12.3M',
        'cover': {'url': 'https://img/artist.jpg'},
        'tracks': [_track('t1')],
        'albums': [
          {'id': 'alb1', 'title': 'Album'},
        ],
        'singles': [
          {'id': 'alb2', 'title': 'Single', 'releaseType': 'single'},
        ],
      });

      expect(artist.verified, isTrue);
      expect(artist.monthlyListeners, '12.3M');
      expect(artist.avatarUrl, 'https://img/artist.jpg');
      expect(artist.tracks.single.id, 't1');
      expect(artist.albums.single.title, 'Album');
      expect(artist.singles.single.id, 'alb2');
    });

    test('accepts a numeric listener count', () {
      expect(
        ArtistDetails.fromJson({
          'id': 'a',
          'monthlyListeners': 1500,
        }).monthlyListeners,
        '1500',
      );
    });
  });

  group('UserPlaylistDetails', () {
    test('keeps the entry id needed to remove a track', () {
      final details = UserPlaylistDetails.fromJson({
        'playlist': {'id': 'p1', 'title': 'Mine'},
        'items': [
          {'id': 'item-1', 'track': _track('t1'), 'position': 0},
          {'id': 'item-2', 'track': _track('t2'), 'position': 1},
          {'id': 'broken'},
        ],
      });

      expect(details.playlist.title, 'Mine');
      expect(details.items.map((i) => i.id), ['item-1', 'item-2']);
      expect(details.tracks.map((t) => t.id), ['t1', 't2']);
    });
  });

  test('search results include albums', () {
    final results = SearchResults.fromJson({
      'items': [
        {'type': 'album', 'id': 'alb1', 'title': 'Album', 'year': 2020},
        {'type': 'track', 'id': 't1', 'title': 'Song'},
      ],
    });

    expect(results.albums.single.year, 2020);
    expect(results.tracks.single.id, 't1');
    expect(results.isEmpty, isFalse);
    expect(SearchResults.fromJson({'items': <Object?>[]}).isEmpty, isTrue);
  });

  group('ImportJob', () {
    test('maps API statuses and keeps unknown ones as running', () {
      expect(ImportStatus.parse('queued'), ImportStatus.queued);
      expect(
        ImportStatus.parse('awaiting_decision'),
        ImportStatus.awaitingDecision,
      );
      expect(ImportStatus.parse('completed').isFinished, isTrue);
      expect(ImportStatus.parse('something_new'), ImportStatus.running);
    });

    test('a worker update keeps what it does not resend', () {
      final job = ImportJob.fromJson({
        'id': 'j1',
        'status': 'queued',
        'title': 'Road trip',
        'importToken': 'tok',
        'workerWsUrl': 'wss://worker/ws',
        'sourceUrl': 'https://open.spotify.com/playlist/x',
      });

      final updated = job.mergedWith({
        'type': 'job',
        'status': 'running',
        'queuePosition': 3,
      });

      expect(updated.status, ImportStatus.running);
      expect(updated.title, 'Road trip');
      expect(updated.importToken, 'tok');
      expect(updated.workerWsUrl, 'wss://worker/ws');
      expect(updated.queuePosition, 3);
    });

    test('reads the result and error details', () {
      final done = ImportJob.fromJson({
        'id': 'j1',
        'status': 'completed',
        'playlistId': 'p1',
        'result': {'total': 10, 'imported': 7, 'skipped': 3},
      });
      final failed = ImportJob.fromJson({
        'id': 'j2',
        'status': 'failed',
        'error': {'code': 'PRIVATE', 'message': 'Playlist is private'},
      });

      expect(done.result?.imported, 7);
      expect(done.playlistId, 'p1');
      expect(failed.errorMessage, 'Playlist is private');
    });
  });

  group('ImportReview', () {
    Map<String, Object?> review(
      String id, {
      String reason = 'ambiguous_match',
      bool proposed = true,
    }) => {
      'id': id,
      'sourceTrack': {
        'sourceId': 's$id',
        'title': 'Source',
        'artists': ['A', 'B'],
        'durationMs': 1000,
      },
      if (proposed) 'proposedTrack': _track('t$id'),
      'reason': reason,
      'position': 1,
    };

    test('keeps the proposed track as the API sent it', () {
      final parsed = ImportReview.tryParse(review('1'))!;

      expect(parsed.source.artistName, 'A, B');
      expect(parsed.proposed?.id, 't1');
      expect(parsed.proposedJson?['id'], 't1');
      expect(ImportReview.tryParse({'id': 'x'}), isNull);
    });

    test('only reviews with a proposal and no duplicates are shown', () {
      final items = reviewableItems([
        ImportReview.tryParse(review('1'))!,
        ImportReview.tryParse(review('1'))!,
        ImportReview.tryParse(review('2', reason: 'no_catalog_candidates'))!,
        ImportReview.tryParse(review('3', proposed: false))!,
        ImportReview.tryParse(review('4'))!,
      ]);

      expect(items.map((i) => i.id), ['1', '4']);
    });

    test('decisions serialize the way the API expects', () {
      expect(
        const ImportReviewDecision(reviewId: 'r1', approve: true).toJson(),
        {'reviewId': 'r1', 'decision': 'approve'},
      );
      expect(
        const ImportReviewDecision(reviewId: 'r2', approve: false).toJson(),
        {'reviewId': 'r2', 'decision': 'deny'},
      );
    });
  });

  group('ImportSources', () {
    test('recognizes the supported services', () {
      expect(
        ImportSources.detect('https://open.spotify.com/playlist/abc'),
        'Spotify',
      );
      expect(
        ImportSources.detect('music.youtube.com/playlist?list=PL1'),
        'YouTube',
      );
      expect(ImportSources.detect('https://youtu.be/xyz'), 'YouTube');
      expect(
        ImportSources.detect('https://soundcloud.com/me/sets/x'),
        'SoundCloud',
      );
      expect(
        ImportSources.detect('https://www.deezer.com/en/playlist/1'),
        'Deezer',
      );
      expect(
        ImportSources.detect('https://music.apple.com/us/playlist/x/pl.1'),
        'Apple Music',
      );
    });

    test('does not recognize unrelated or malformed links', () {
      expect(ImportSources.detect('https://example.com/playlist'), isNull);
      expect(ImportSources.detect('not a link'), isNull);
      expect(ImportSources.detect(''), isNull);
    });

    test('adds the scheme and rejects unusable text', () {
      expect(
        ImportSources.normalize('open.spotify.com/playlist/x').toString(),
        'https://open.spotify.com/playlist/x',
      );
      expect(ImportSources.normalize('  '), isNull);
      expect(ImportSources.normalize('hello'), isNull);
    });

    test('builds the SoundCloud likes link from a username', () {
      expect(
        ImportSources.soundCloudLikesUrl('@some user'),
        'https://soundcloud.com/some%20user/likes',
      );
      expect(
        ImportSources.soundCloudLikesUrl('https://soundcloud.com/x/likes'),
        'https://soundcloud.com/x/likes',
      );
    });
  });
}
