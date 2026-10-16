import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liner_mobile/core/api/liner_api.dart';
import 'package:liner_mobile/core/models/track.dart';
import 'package:liner_mobile/providers/player_provider.dart';
import 'package:liner_mobile/services/audio_player_service.dart';
import 'package:liner_mobile/ui/screens/player/lyrics_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_api.dart';
import '../support/fake_audio_engine.dart';

void main() {
  late AudioPlayerService service;
  late List<Object> lyricsEvents;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    lyricsEvents = [];
    final adapter = FakeAdapter((RequestOptions options) {
      final path = options.path;
      if (path.endsWith('/playback')) {
        return jsonResponse({'streamUrl': '/v1/playback/t1/media'});
      }
      if (path.endsWith('/lyrics')) return sseResponse(lyricsEvents);
      if (path.endsWith('/radio')) return jsonResponse({'items': <Object?>[]});
      return jsonResponse(null, status: 204);
    });
    service = AudioPlayerService(
      LinerApi(clientWith(adapter)),
      engine: FakeAudioEngine(),
    )..autoplaySimilar = false;
    addTearDown(service.dispose);
  });

  Future<void> showLyrics(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [playerServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(home: Scaffold(body: LyricsView())),
      ),
    );
    await tester.runAsync(() async {
      await service.playTrack(
        const Track(id: 't1', title: 'Song', durationMs: 200000),
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pump();
  }

  List<Object> threeProviders() => [
    lyricsProviderEvent('Plain', 'plain', 'just words', 'plain', 99),
    lyricsProviderEvent('Line', 'lrc', '[00:01.00]line text', 'line_level', 50),
    lyricsProviderEvent(
      'Syllable',
      'ttml',
      '<tt><body><p begin="2s" end="4s">syllable text</p></body></tt>',
      'syllable_level',
      10,
    ),
  ];

  testWidgets('says so when no provider has lyrics', (tester) async {
    await showLyrics(tester);

    expect(find.text('No lyrics available for this track'), findsOneWidget);
    expect(find.byTooltip('Next provider'), findsNothing);
  });

  testWidgets('shows the best provider and steps through the others', (
    tester,
  ) async {
    lyricsEvents = threeProviders();
    await showLyrics(tester);

    expect(find.text('Syllable'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
    expect(find.text('syllable text'), findsOneWidget);

    await tester.tap(find.byTooltip('Next provider'));
    await tester.pump();
    expect(find.text('Line'), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);
    expect(find.text('line text'), findsOneWidget);

    await tester.tap(find.byTooltip('Previous provider'));
    await tester.pump();
    expect(find.text('Syllable'), findsOneWidget);
  });

  testWidgets('picks a provider from the list', (tester) async {
    lyricsEvents = threeProviders();
    await showLyrics(tester);

    await tester.tap(find.text('1/3'));
    await tester.pumpAndSettle();
    expect(find.text('Lyrics source'), findsOneWidget);
    expect(find.text('Word synced'), findsNothing);
    expect(find.text('Not synced'), findsOneWidget);

    await tester.tap(find.text('Line').last);
    await tester.pumpAndSettle();

    expect(find.text('Lyrics source'), findsNothing);
    expect(find.text('line text'), findsOneWidget);
    expect(service.currentState.activeLyricsProvider, 'Line');
  });

  testWidgets('shows unsynced lyrics as static text without timing', (
    tester,
  ) async {
    lyricsEvents = [
      lyricsProviderEvent('Plain', 'plain', 'just words', 'plain', 99),
    ];
    await showLyrics(tester);

    expect(find.text('just words'), findsOneWidget);
    expect(find.byTooltip('Show lyrics later'), findsNothing);
  });

  testWidgets('nudges and resets the timing offset', (tester) async {
    lyricsEvents = threeProviders();
    await showLyrics(tester);
    expect(find.text('0.0s'), findsOneWidget);

    await tester.tap(find.byTooltip('Show lyrics later'));
    await tester.pump();
    expect(find.text('+0.1s'), findsOneWidget);
    expect(service.currentState.lyricsOffsetMs, 100);

    await tester.tap(find.text('+0.1s'));
    await tester.pumpAndSettle();
    expect(find.text('Lyrics timing'), findsOneWidget);

    await tester.tap(find.text('+1.0s'));
    await tester.pump();
    expect(service.currentState.lyricsOffsetMs, 1100);

    await tester.tap(find.byTooltip('Earlier by 50 ms'));
    await tester.pump();
    expect(service.currentState.lyricsOffsetMs, 1050);
    expect(find.text('+1.05s'), findsWidgets);

    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(service.currentState.lyricsOffsetMs, 0);
  });
}
