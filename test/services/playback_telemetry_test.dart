import 'package:flutter_test/flutter_test.dart';
import 'package:liner_mobile/core/models/playback_event.dart';
import 'package:liner_mobile/core/models/track.dart';
import 'package:liner_mobile/services/playback_telemetry.dart';

void main() {
  const track = Track(id: 't1', title: 'Song', durationMs: 200000);
  const other = Track(id: 't2', title: 'Other', durationMs: 100000);

  late DateTime now;
  late List<PlaybackEvent> events;
  late PlaybackTelemetry telemetry;
  var ids = 0;

  void elapse(Duration duration) => now = now.add(duration);

  void listen(Duration duration) {
    telemetry.onPlaying();
    elapse(duration);
    telemetry.onPausedOrStopped();
  }

  setUp(() {
    now = DateTime(2026, 10, 17, 12);
    events = [];
    ids = 0;
    telemetry = PlaybackTelemetry(
      onEvent: events.add,
      clock: () => now,
      newId: () => 'id-${ids++}',
    );
  });

  test('ignores tracks listened to for under 3 seconds', () {
    telemetry.startTrack(track, null);
    listen(const Duration(seconds: 2));
    telemetry.flush();

    expect(events, isEmpty);
  });

  test('reports a short listen as skipped with its completion rate', () {
    telemetry.startTrack(track, PlaybackContext.search);
    listen(const Duration(seconds: 10));
    telemetry.flush();

    final event = events.single;
    expect(event.trackId, 't1');
    expect(event.playedDurationMs, 10000);
    expect(event.trackDurationMs, 200000);
    expect(event.completionRate, 0.05);
    expect(event.skipped, isTrue);
    expect(event.completed, isFalse);
    expect(event.context?.type, 'search');
  });

  test('a completed track is not a skip and the rate is capped at 1', () {
    telemetry.startTrack(track, null);
    listen(const Duration(seconds: 230));
    telemetry.onCompleted(repeatOne: false);
    telemetry.flush();

    final event = events.single;
    expect(event.completed, isTrue);
    expect(event.skipped, isFalse);
    expect(event.completionRate, 1.0);
  });

  test('a track played past the skip threshold is not a skip', () {
    telemetry.startTrack(track, null);
    listen(const Duration(seconds: 45));
    telemetry.flush();

    expect(events.single.skipped, isFalse);
  });

  test('time spent paused does not count as listening', () {
    telemetry.startTrack(track, null);
    listen(const Duration(seconds: 10));
    elapse(const Duration(minutes: 5));
    listen(const Duration(seconds: 5));
    telemetry.flush();

    expect(events.single.playedDurationMs, 15000);
  });

  test('starting another track reports the previous one first', () {
    telemetry.startTrack(track, PlaybackContext.explore);
    listen(const Duration(seconds: 40));
    telemetry.startTrack(other, null);

    expect(events, hasLength(1));
    expect(events.single.trackId, 't1');
    expect(events.single.context?.type, 'explore');

    listen(const Duration(seconds: 6));
    telemetry.flush();
    expect(events.last.trackId, 't2');
    expect(events.last.context, isNull);
  });

  test('every track gets its own playback session id', () {
    telemetry.startTrack(track, null);
    listen(const Duration(seconds: 10));
    telemetry.startTrack(other, null);
    listen(const Duration(seconds: 10));
    telemetry.flush();

    expect(events[0].playbackSessionId, isNot(events[1].playbackSessionId));
  });

  test('records backward seeks and repeat-one loops', () {
    telemetry.startTrack(track, null);
    listen(const Duration(seconds: 20));
    telemetry.onSeekBackward();
    telemetry.onCompleted(repeatOne: true);
    listen(const Duration(seconds: 20));
    telemetry.onCompleted(repeatOne: true);
    telemetry.flush();

    final event = events.single;
    expect(event.hasSeekBackward, isTrue);
    expect(event.loopCount, 2);
    expect(event.playedDurationMs, 40000);
  });

  test('the listening session rotates after 30 minutes of inactivity', () {
    telemetry.startTrack(track, null);
    listen(const Duration(seconds: 10));
    elapse(const Duration(minutes: 29));
    telemetry.startTrack(other, null);
    listen(const Duration(seconds: 10));
    elapse(const Duration(minutes: 31));
    telemetry.startTrack(track, null);
    listen(const Duration(seconds: 10));
    telemetry.flush();

    expect(events, hasLength(3));
    expect(events[0].listeningSessionId, events[1].listeningSessionId);
    expect(events[1].listeningSessionId, isNot(events[2].listeningSessionId));
  });

  test('flushing with nothing playing reports nothing', () {
    telemetry.flush();

    expect(events, isEmpty);
  });

  group('PlaybackEvent.toJson', () {
    test('matches the API contract and omits unknown optional fields', () {
      const event = PlaybackEvent(
        playbackSessionId: 'ps',
        listeningSessionId: 'ls',
        trackId: 't1',
        playedDurationMs: 1000,
        completionRate: 0.5,
        completed: false,
        skipped: true,
        loopCount: 0,
        hasSeekBackward: false,
      );

      expect(event.toJson(), {
        'playbackSessionId': 'ps',
        'listeningSessionId': 'ls',
        'trackId': 't1',
        'playedDurationMs': 1000,
        'completionRate': 0.5,
        'completed': false,
        'skipped': true,
        'loopCount': 0,
        'hasSeekBackward': false,
      });
    });

    test('includes the playlist context id', () {
      expect(const PlaybackContext.playlist('p1').toJson(), {
        'type': 'playlist',
        'id': 'p1',
      });
    });
  });
}
