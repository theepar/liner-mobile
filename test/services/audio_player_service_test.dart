import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liner_mobile/core/api/liner_api.dart';
import 'package:liner_mobile/core/models/playback_event.dart';
import 'package:liner_mobile/core/models/player_state.dart';
import 'package:liner_mobile/core/models/track.dart';
import 'package:liner_mobile/services/audio_player_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_api.dart';
import '../support/fake_audio_engine.dart';

Track _track(String id, {int durationMs = 200000}) =>
    Track(id: id, title: 'Track $id', durationMs: durationMs);

void main() {
  late FakeAudioEngine engine;
  late AudioPlayerService service;
  late List<RequestOptions> requests;
  late DateTime now;
  late Map<String, Completer<ResponseBody>> gates;
  late Object? Function(String trackId) lyricsFor;
  late bool streamAvailable;

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 60));

  Iterable<Map<String, Object?>> events() => [
    for (final request in requests)
      if (request.path == '/v1/me/playback/events')
        request.data as Map<String, Object?>,
  ];

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    engine = FakeAudioEngine();
    requests = [];
    gates = {};
    streamAvailable = true;
    now = DateTime(2026, 10, 17, 12);
    lyricsFor = (_) => <Object>[];
    final adapter = FakeAdapter((options) {
      requests.add(options);
      final path = options.path;
      if (path.endsWith('/playback')) {
        final id = path.split('/')[3];
        final gate = gates[id];
        if (gate != null) return gate.future;
        return streamAvailable
            ? jsonResponse({'streamUrl': '/v1/playback/$id/media'})
            : jsonResponse({'transport': 'direct_innertube'});
      }
      if (path.endsWith('/lyrics')) {
        final id = path.split('/')[3];
        return sseResponse(lyricsFor(id) as List<Object>);
      }
      if (path.endsWith('/radio')) return jsonResponse({'items': <Object?>[]});
      return jsonResponse(null, status: 204);
    });
    service = AudioPlayerService(
      LinerApi(clientWith(adapter)),
      engine: engine,
      clock: () => now,
    )..autoplaySimilar = false;
  });

  tearDown(() async {
    await service.dispose();
  });

  group('starting playback', () {
    test('asks for a proxy stream, loads it and plays', () async {
      await service.playTrack(_track('a'));
      await settle();

      final playback = requests.firstWhere((r) => r.path.endsWith('/playback'));
      expect(playback.data, {'transport': 'proxy'});
      expect(engine.loadedUrl, endsWith('/v1/playback/a/media'));
      expect(engine.calls, contains('play'));
      expect(service.currentState.status, PlaybackStatus.playing);
      expect(service.currentState.currentTrack?.id, 'a');
    });

    test('asks for AAC when high quality is on', () async {
      service.highQuality = true;

      await service.playTrack(_track('a'));
      await settle();

      final playback = requests.firstWhere((r) => r.path.endsWith('/playback'));
      expect(playback.data, {'transport': 'proxy', 'preferredCodec': 'aac'});
    });

    test('always asks for AAC on iOS, which cannot play Opus', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      await service.playTrack(_track('a'));
      await settle();

      final playback = requests.firstWhere((r) => r.path.endsWith('/playback'));
      expect(playback.data, {'transport': 'proxy', 'preferredCodec': 'aac'});
    });

    test('reports an error when the server has no stream', () async {
      streamAvailable = false;

      await service.playTrack(_track('a'));
      await settle();

      expect(service.currentState.status, PlaybackStatus.error);
      expect(engine.calls.where((c) => c.startsWith('setUrl')), isEmpty);
    });

    test('pressing play after an error tries the track again', () async {
      streamAvailable = false;
      await service.playTrack(_track('a'));
      await settle();
      streamAvailable = true;

      await service.play();
      await settle();

      expect(service.currentState.status, PlaybackStatus.playing);
    });

    test(
      'a failure while loading the stream is an error, not a crash',
      () async {
        engine.setUrlError = Exception('decoder failed');

        await service.playTrack(_track('a'));
        await settle();

        expect(service.currentState.status, PlaybackStatus.error);
      },
    );

    test('a track chosen later wins over a slow earlier request', () async {
      gates['slow'] = Completer<ResponseBody>();

      final first = service.playTrack(_track('slow'));
      await settle();
      await service.playTrack(_track('fast'));
      await settle();
      gates['slow']!.complete(
        jsonResponse({'streamUrl': '/v1/playback/slow/media'}),
      );
      await first;
      await settle();

      expect(engine.loadedUrl, endsWith('/v1/playback/fast/media'));
      expect(engine.calls.where((c) => c.startsWith('setUrl')), hasLength(1));
      expect(service.currentState.currentTrack?.id, 'fast');
    });
  });

  group('lyrics', () {
    Map<String, Object?> lrc(String text) => {
      'type': 'provider',
      'provider': 'LRCLIB',
      'status': 'found',
      'candidate': {
        'lyrics': {'format': 'lrc', 'content': '[00:01.00]$text'},
        'syncLevel': 'line_level',
        'quality': {'total': 80},
      },
    };

    test('load alongside playback for the current track', () async {
      lyricsFor = (id) => [lrc('Hello $id')];

      await service.playTrack(_track('a'));
      await settle();

      expect(service.currentState.lyrics.single.text, 'Hello a');
      expect(service.currentState.isLoadingLyrics, isFalse);
    });

    test('are cleared when the next track starts', () async {
      lyricsFor = (id) => id == 'a' ? [lrc('Hello a')] : <Object>[];

      await service.playTrack(_track('a'));
      await settle();
      await service.playTrack(_track('b'));
      await settle();

      expect(service.currentState.lyrics, isEmpty);
    });

    List<Object> allProviders(String _) => [
      lyricsProviderEvent('Plain', 'plain', 'just words', 'plain', 99),
      lyricsProviderEvent('Line', 'lrc', '[00:01.00]line', 'line_level', 50),
      lyricsProviderEvent(
        'Syllable',
        'ttml',
        '<tt><body><p begin="2s" end="4s">syllable</p></body></tt>',
        'syllable_level',
        10,
      ),
    ];

    test('offer every provider and show the best synced one', () async {
      lyricsFor = allProviders;

      await service.playTrack(_track('a'));
      await settle();

      final state = service.currentState;
      expect(state.lyricsOptions.map((o) => o.provider), [
        'Syllable',
        'Line',
        'Plain',
      ]);
      expect(state.activeLyricsProvider, 'Syllable');
      expect(state.lyrics.single.text, 'syllable');
    });

    test('switch to another provider on request', () async {
      lyricsFor = allProviders;
      await service.playTrack(_track('a'));
      await settle();

      service.selectLyricsProvider('Plain');
      expect(service.currentState.activeLyricsProvider, 'Plain');
      expect(service.currentState.lyrics, isEmpty);
      expect(service.currentState.lyricsPlainText, 'just words');

      service.selectLyricsProvider('Line');
      expect(service.currentState.lyrics.single.text, 'line');
      expect(service.currentState.lyricsPlainText, isNull);
    });

    test('shift with a timing offset remembered for that track', () async {
      lyricsFor = allProviders;
      await service.playTrack(_track('a'));
      await settle();
      service.selectLyricsProvider('Line');

      await service.setLyricsOffset(500);
      expect(service.currentState.lyricsOffsetMs, 500);
      expect(service.currentState.lyrics.single.startMs, 1500);

      await service.playTrack(_track('b'));
      await settle();
      expect(service.currentState.lyricsOffsetMs, 0);

      await service.playTrack(_track('a'));
      await settle();
      expect(service.currentState.lyricsOffsetMs, 500);
      expect(service.currentState.lyrics.single.startMs, 2500);
    });
  });

  group('moving through the queue', () {
    test('the next track starts when one finishes', () async {
      await service.setQueue([_track('a'), _track('b')]);
      await settle();

      engine.complete();
      await settle();

      expect(service.currentState.currentTrack?.id, 'b');
      expect(service.currentState.currentIndex, 1);
    });

    test('repeat one plays the same track again', () async {
      service
        ..cycleRepeatMode()
        ..cycleRepeatMode();
      expect(service.currentState.repeatMode, LinerRepeatMode.one);
      await service.setQueue([_track('a'), _track('b')]);
      await settle();

      engine.complete();
      await settle();

      expect(service.currentState.currentTrack?.id, 'a');
      expect(engine.calls, contains('seek:0'));
    });

    test('the last track ends the queue without jumping back', () async {
      await service.setQueue([_track('a')]);
      await settle();

      engine.complete();
      await settle();

      expect(service.currentState.currentTrack?.id, 'a');
      expect(service.currentState.status, PlaybackStatus.completed);
    });

    test('previous restarts a track that has played for a while', () async {
      await service.setQueue([_track('a'), _track('b')], startIndex: 1);
      await settle();
      service.addToQueue(_track('c'));
      engine.emitPosition(const Duration(seconds: 10));
      await settle();

      await service.previous();

      expect(service.currentState.currentTrack?.id, 'b');
      expect(engine.calls, contains('seek:0'));
    });

    test(
      'previous within the first seconds goes to the earlier track',
      () async {
        await service.setQueue([_track('a'), _track('b')], startIndex: 1);
        await settle();

        await service.previous();
        await settle();

        expect(service.currentState.currentTrack?.id, 'a');
      },
    );

    test('shuffle never repeats the current track', () async {
      await service.setQueue([_track('a'), _track('b'), _track('c')]);
      service.toggleShuffle();
      await settle();

      for (var i = 0; i < 20; i++) {
        final before = service.currentState.currentTrack?.id;
        await service.next();
        expect(service.currentState.currentTrack?.id, isNot(before));
      }
    });

    test('stopping clears the queue and the player', () async {
      await service.setQueue([_track('a'), _track('b')]);
      await settle();

      await service.stop();

      expect(service.currentState.currentTrack, isNull);
      expect(service.currentState.queue, isEmpty);
      expect(engine.calls.last, 'stop');
    });
  });

  group('listening reports', () {
    test(
      'a track listened to for a while is reported when the next starts',
      () async {
        await service.setQueue([
          _track('a'),
          _track('b'),
        ], context: PlaybackContext.search);
        await settle();
        now = now.add(const Duration(seconds: 45));

        await service.next();
        await settle();

        final report = events().single;
        expect(report['trackId'], 'a');
        expect(report['playedDurationMs'], 45000);
        expect(report['skipped'], isFalse);
        expect(report['context'], {'type': 'search'});
      },
    );

    test('finishing the last track reports it as completed', () async {
      await service.setQueue([_track('a', durationMs: 60000)]);
      await settle();
      now = now.add(const Duration(seconds: 60));

      engine.complete();
      await settle();

      final report = events().single;
      expect(report['completed'], isTrue);
      expect(report['completionRate'], 1.0);
    });

    test('a quick skip is not reported', () async {
      await service.setQueue([_track('a'), _track('b')]);
      await settle();
      now = now.add(const Duration(seconds: 1));

      await service.next();
      await settle();

      expect(events(), isEmpty);
    });

    test('stopping flushes what was listened to', () async {
      await service.setQueue([_track('a')]);
      await settle();
      now = now.add(const Duration(seconds: 20));

      await service.stop();
      await settle();

      expect(events().single['skipped'], isTrue);
      expect(events().single['playedDurationMs'], 20000);
    });
  });

  group('controls', () {
    test('speed and pitch are applied and reflected in the state', () async {
      await service.setSpeed(1.5);
      await service.setPitch(0.9);

      expect(engine.calls, containsAll(['speed:1.5', 'pitch:0.9']));
      expect(service.currentState.playbackSpeed, 1.5);
      expect(service.currentState.pitch, 0.9);
    });

    test('toggling play and pause follows the engine', () async {
      await service.playTrack(_track('a'));
      await settle();

      await service.togglePlayPause();
      await settle();
      expect(service.currentState.status, PlaybackStatus.paused);

      await service.togglePlayPause();
      await settle();
      expect(service.currentState.status, PlaybackStatus.playing);
    });
  });
}
