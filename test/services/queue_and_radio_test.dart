import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liner_mobile/core/api/liner_api.dart';
import 'package:liner_mobile/core/models/player_state.dart';
import 'package:liner_mobile/core/models/track.dart';
import 'package:liner_mobile/services/audio_player_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_api.dart';
import '../support/fake_audio_engine.dart';

Track _track(String id) => Track(id: id, title: 'Track $id');

void main() {
  late List<RequestOptions> requests;
  late List<String> radioIds;
  late AudioPlayerService service;

  List<String> queueIds() => [
    for (final track in service.currentState.queue) track.id,
  ];

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 80));

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    requests = [];
    radioIds = ['r1', 'r2', 'r3'];
    final adapter = FakeAdapter((options) {
      requests.add(options);
      if (options.path.endsWith('/radio')) {
        return jsonResponse({
          'items': [for (final id in radioIds) trackJson(id)],
        });
      }
      if (options.path.endsWith('/lyrics')) return sseResponse([]);
      if (options.path.endsWith('/playback')) {
        return jsonResponse({'streamUrl': '/v1/playback/pb/media'});
      }
      return jsonResponse(null, status: 204);
    });
    service = AudioPlayerService(
      LinerApi(clientWith(adapter)),
      engine: FakeAudioEngine(),
    );
  });

  tearDown(() async {
    await service.dispose();
  });

  Iterable<RequestOptions> radioRequests() =>
      requests.where((r) => r.path.endsWith('/radio'));

  group('queue', () {
    test('play next inserts right after the current track', () async {
      await service.setQueue([_track('a'), _track('b'), _track('c')]);

      service.addToQueue(_track('x'), next: true);

      expect(queueIds(), ['a', 'x', 'b', 'c']);
      expect(service.currentState.currentIndex, 0);
    });

    test('add to queue appends at the end', () async {
      await service.setQueue([_track('a'), _track('b'), _track('c')]);

      service.addToQueue(_track('x'));

      expect(queueIds(), ['a', 'b', 'c', 'x']);
    });

    test('a track played on its own gets a queue when one is needed', () async {
      service.autoplaySimilar = false;
      await service.playTrack(_track('solo'));
      service.addToQueue(_track('x'));

      expect(queueIds(), ['solo', 'x']);
      expect(service.currentState.currentIndex, 0);
    });

    test('adding with nothing playing starts that track', () async {
      service.addToQueue(_track('x'));
      await settle();

      expect(service.currentState.currentTrack?.id, 'x');
    });

    test('skip to jumps to a queue position', () async {
      await service.setQueue([_track('a'), _track('b'), _track('c')]);

      await service.skipTo(2);

      expect(service.currentState.currentTrack?.id, 'c');
      expect(service.currentState.currentIndex, 2);
    });

    test('skip to ignores positions outside the queue', () async {
      await service.setQueue([_track('a'), _track('b')]);

      await service.skipTo(5);

      expect(service.currentState.currentTrack?.id, 'a');
    });
  });

  group('radio', () {
    test('a station fills the queue with similar tracks', () async {
      await service.startRadio(_track('seed'));
      await settle();

      expect(queueIds(), ['seed', 'r1', 'r2', 'r3']);
      final request = radioRequests().single;
      expect(request.method, 'POST');
      expect(request.path, '/v1/tracks/seed/radio');
      final body = request.data as Map<String, Object?>;
      expect(body['history'], ['seed']);
      expect(body['wave_id'], isA<String>());
    });

    test('tracks already queued are not added again', () async {
      radioIds = ['seed', 'r1'];

      await service.startRadio(_track('seed'));
      await settle();

      expect(queueIds(), ['seed', 'r1']);
    });

    test('nothing is fetched when autoplay is turned off', () async {
      service.autoplaySimilar = false;

      await service.setQueue([_track('a')]);
      await settle();

      expect(radioRequests(), isEmpty);
      expect(queueIds(), ['a']);
    });

    test(
      'nothing is fetched while the queue still has upcoming tracks',
      () async {
        await service.setQueue([_track('a'), _track('b'), _track('c')]);
        await settle();

        expect(radioRequests(), isEmpty);
      },
    );

    test('nothing is fetched while repeating the queue', () async {
      service.cycleRepeatMode();
      expect(service.currentState.repeatMode, LinerRepeatMode.all);

      await service.setQueue([_track('a')]);
      await settle();

      expect(radioRequests(), isEmpty);
    });

    test('the same wave is used for later top-ups of one queue', () async {
      radioIds = ['r1'];
      await service.setQueue([_track('a')]);
      await settle();
      radioIds = ['r2'];
      await service.skipTo(1);
      await settle();

      final waves = [
        for (final request in radioRequests())
          (request.data as Map<String, Object?>)['wave_id'],
      ];
      expect(waves, hasLength(2));
      expect(waves.first, waves.last);
    });

    test('a failing station leaves the queue untouched', () async {
      final failing = AudioPlayerService(
        LinerApi(
          clientWith(
            FakeAdapter((options) {
              if (options.path.endsWith('/lyrics')) return sseResponse([]);
              return jsonResponse({}, status: 500);
            }),
          ),
        ),
        engine: FakeAudioEngine(),
      );

      await failing.setQueue([_track('a')]);
      await settle();

      expect(failing.currentState.queue.map((t) => t.id), ['a']);
      await failing.dispose();
    });
  });
}
