import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liner_mobile/core/config/app_config.dart';
import 'package:liner_mobile/providers/api_provider.dart';
import 'package:liner_mobile/providers/app_info_provider.dart';
import 'package:liner_mobile/providers/player_provider.dart';
import 'package:liner_mobile/providers/storage_provider.dart';
import 'package:liner_mobile/services/audio_player_service.dart';
import 'package:liner_mobile/services/cover_image_cache.dart';
import 'package:liner_mobile/ui/navigation/auth_gate.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/app_harness.dart';
import '../support/fake_api.dart' show jsonResponse;
import '../support/fake_audio_engine.dart';

class _FakeCache implements DeviceCache {
  _FakeCache(this.bytes);

  int bytes;
  int clears = 0;

  @override
  Future<int> sizeBytes() async => bytes;

  @override
  Future<void> clear() async {
    clears++;
    bytes = 0;
  }
}

bool _drawsLogo(Widget widget, String id) =>
    widget is SvgPicture &&
    widget.bytesLoader is SvgAssetLoader &&
    (widget.bytesLoader as SvgAssetLoader).assetName ==
        'assets/branding/logos/$id.svg';

void main() {
  late List<RequestOptions> log;

  setUp(() => log = []);

  Future<void> openSettings(
    WidgetTester tester, {
    List<Override> overrides = const [],
    Map<String, Object> preferences = const {},
    Map<String, RouteHandler> routes = const {},
    Size size = const Size(800, 2000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await signedInApp(
      tester,
      fakeBackend(log: log, routes: routes),
      overrides: overrides,
      preferences: preferences,
    );
    await openTab(tester, 'Settings');
  }

  Future<void> openPage(WidgetTester tester, String title) async {
    await tester.ensureVisible(find.text(title));
    await tester.pumpAndSettle();
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  Future<Object?> storedPreference(String key) async =>
      (await SharedPreferences.getInstance()).get(key);

  testWidgets('every page fits a small phone without overflowing', (
    tester,
  ) async {
    await openSettings(tester, size: const Size(320, 640));
    expect(tester.takeException(), isNull, reason: 'hub');

    for (final title in [
      'Playback',
      'Audio',
      'Appearance',
      'Cache & Storage',
      'About',
    ]) {
      await openPage(tester, title);
      expect(tester.takeException(), isNull, reason: title);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  group('settings hub', () {
    testWidgets('lists every page and the signed-in account', (tester) async {
      await openSettings(tester);

      for (final label in [
        'Playback',
        'Audio',
        'Appearance',
        'Cache & Storage',
        'About',
        'Docs',
        'Support',
        '@me',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('search finds a single setting and opens its page', (
      tester,
    ) async {
      await openSettings(tester);

      await tester.enterText(find.byType(TextField), 'brand');
      await tester.pumpAndSettle();
      expect(find.text('Branding'), findsOneWidget);
      expect(find.text('Playback'), findsNothing);

      await tester.tap(find.text('Branding'));
      await tester.pumpAndSettle();
      expect(find.text('Choose the logo style.'), findsOneWidget);
    });

    testWidgets('search says when nothing matches', (tester) async {
      await openSettings(tester);

      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pumpAndSettle();

      expect(find.text('No settings match your search'), findsOneWidget);
    });

    testWidgets('signing out asks for confirmation first', (tester) async {
      await openSettings(tester);

      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();
      expect(find.text('Are you sure you want to sign out?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Are you sure you want to sign out?'), findsNothing);
      expect(find.byType(AuthGate), findsOneWidget);
      expect(find.text('Sign in to Liner'), findsNothing);
    });

    testWidgets('help links open outside the app', (tester) async {
      final opened = <Uri>[];
      await openSettings(
        tester,
        overrides: [
          linkLauncherProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return true;
          }),
        ],
      );

      await tester.tap(find.text('Docs'));
      await tester.pump();
      await tester.tap(find.text('Support'));
      await tester.pump();

      expect(opened, [
        Uri.parse(AppConfig.docsUrl),
        Uri.parse(AppConfig.supportUrl),
      ]);
    });

    testWidgets('a link that cannot be opened says so', (tester) async {
      await openSettings(
        tester,
        overrides: [linkLauncherProvider.overrideWithValue((_) async => false)],
      );

      await tester.tap(find.text('Docs'));
      await tester.pump();

      expect(find.text('Could not open the link.'), findsOneWidget);
    });

    testWidgets('reset restores defaults after confirming', (tester) async {
      await openSettings(
        tester,
        preferences: {
          'liner_autoplay_similar': false,
          'liner_branding': 'aurora',
        },
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );

      await tester.tap(find.text('Reset to defaults'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Reset'));
      await tester.pumpAndSettle();

      expect(await storedPreference('liner_autoplay_similar'), isNull);
      expect(await storedPreference('liner_branding'), isNull);
    });
  });

  group('playback page', () {
    testWidgets('autoplay similar tracks can be switched off', (tester) async {
      await openSettings(tester);
      await openPage(tester, 'Playback');
      final toggle = find.widgetWithText(
        SwitchListTile,
        'Autoplay similar tracks',
      );
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      expect(await storedPreference('liner_autoplay_similar'), isFalse);
    });

    testWidgets('the tap action is remembered', (tester) async {
      await openSettings(tester);
      await openPage(tester, 'Playback');

      await tester.tap(find.text('Add to queue'));
      await tester.pumpAndSettle();

      expect(await storedPreference('liner_track_tap_action'), 'queue');
    });

    testWidgets('tapping a song queues it while something is playing', (
      tester,
    ) async {
      final engine = FakeAudioEngine();
      late AudioPlayerService service;
      await signedInApp(
        tester,
        fakeBackend(
          log: log,
          routes: {
            'GET /v1/explore/popular': (_) => {
              'items': [
                {'rank': 1, 'track': plainTrack('t1', title: 'First Song')},
                {'rank': 2, 'track': plainTrack('t2', title: 'Second Song')},
              ],
            },
            'POST /v1/tracks/t1/playback': (_) => {
              'streamUrl': '/v1/playback/t1/media',
            },
          },
        ),
        preferences: {'liner_track_tap_action': 'queue'},
        overrides: [
          playerServiceProvider.overrideWith((ref) {
            service = AudioPlayerService(
              ref.watch(linerApiProvider),
              engine: engine,
            )..autoplaySimilar = false;
            return service;
          }),
        ],
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );

      await tester.tap(find.text('First Song'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump();
      expect(service.currentState.currentTrack?.id, 't1');

      await tester.tap(find.text('Second Song'));
      await tester.pump();

      expect(service.currentState.currentTrack?.id, 't1');
      expect(service.currentState.queue.map((t) => t.id), contains('t2'));
      expect(find.text('Added to queue'), findsOneWidget);
      await tester.pump(const Duration(seconds: 21));
    });
  });

  group('audio page', () {
    testWidgets('high quality is remembered', (tester) async {
      await openSettings(tester);
      await openPage(tester, 'Audio');

      await tester.tap(find.text('High'));
      await tester.pumpAndSettle();

      expect(await storedPreference('liner_high_quality_audio'), isTrue);
    });

    testWidgets('testing the connection shows the latency', (tester) async {
      await openSettings(
        tester,
        routes: {
          'GET ${AppConfig.primaryApiUrl}/health': (_) => {'status': 'ok'},
        },
      );
      await openPage(tester, 'Audio');
      await tester.scrollUntilVisible(
        find.text('Test connection'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Test'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Reachable in'), findsOneWidget);
    });

    testWidgets('a failing server is reported', (tester) async {
      await openSettings(
        tester,
        routes: {
          'GET ${AppConfig.primaryApiUrl}/health': (_) =>
              jsonResponse({}, status: 503),
        },
      );
      await openPage(tester, 'Audio');
      await tester.scrollUntilVisible(
        find.text('Test connection'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Test'));
      await tester.pumpAndSettle();

      expect(find.text('Server answered with HTTP 503'), findsOneWidget);
    });
  });

  group('appearance page', () {
    testWidgets('choosing a branding changes the logo and is remembered', (
      tester,
    ) async {
      await openSettings(tester);
      await openPage(tester, 'Appearance');

      await tester.tap(find.text('Aurora'));
      await tester.pumpAndSettle();

      expect(await storedPreference('liner_branding'), 'aurora');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await openTab(tester, 'Home');

      expect(
        find.byWidgetPredicate((widget) => _drawsLogo(widget, 'aurora')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((widget) => _drawsLogo(widget, 'default')),
        findsNothing,
      );
    });

    testWidgets('offers every logo variant', (tester) async {
      await openSettings(tester);
      await openPage(tester, 'Appearance');

      for (final label in ['Default', 'Spotify', 'Discord', 'Telegram']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      await tester.scrollUntilVisible(
        find.text('Chrome'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Chrome'), findsOneWidget);
    });

    testWidgets('the animated background can be turned off', (tester) async {
      await openSettings(tester);
      await openPage(tester, 'Appearance');
      final toggle = find.widgetWithText(SwitchListTile, 'Animated background');
      await tester.scrollUntilVisible(
        toggle,
        200,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(await storedPreference('liner_animated_background'), isFalse);
    });
  });

  group('storage page', () {
    testWidgets('shows what is stored and clears the chosen categories', (
      tester,
    ) async {
      final covers = _FakeCache(3 * 1024 * 1024);
      final audio = _FakeCache(0);
      await openSettings(
        tester,
        preferences: {
          'liner_search_history': ['one', 'two'],
        },
        overrides: [
          coverCacheProvider.overrideWithValue(covers),
          audioCacheProvider.overrideWithValue(audio),
        ],
      );
      await openPage(tester, 'Cache & Storage');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();

      expect(find.text('3.0 MB'), findsWidgets);
      expect(find.textContaining('Clear Cache (3.0 MB'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Clear Cache (3.0 MB)'),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();

      expect(covers.clears, 1);
      expect(find.text('Cache is squeaky clean!'), findsOneWidget);
    });

    testWidgets('only the ticked categories are cleared', (tester) async {
      final covers = _FakeCache(2048);
      final audio = _FakeCache(0);
      await openSettings(
        tester,
        overrides: [
          coverCacheProvider.overrideWithValue(covers),
          audioCacheProvider.overrideWithValue(audio),
        ],
      );
      await openPage(tester, 'Cache & Storage');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();

      await tester.tap(find.text('Cover Artwork'));
      await tester.pump();

      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(covers.clears, 0);
    });
  });

  testWidgets('language choice is remembered', (tester) async {
    await openSettings(tester);
    await openPage(tester, 'Language');

    await tester.tap(find.text('Русский'));
    await tester.pumpAndSettle();

    expect(await storedPreference('liner_locale'), 'russian');
  });

  group('about page', () {
    testWidgets('shows the app version and opens the community links', (
      tester,
    ) async {
      PackageInfo.setMockInitialValues(
        appName: 'Liner',
        packageName: 'fun.tryliner.mobile',
        version: '1.0.4',
        buildNumber: '7',
        buildSignature: '',
      );
      final opened = <Uri>[];
      await openSettings(
        tester,
        overrides: [
          linkLauncherProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return true;
          }),
        ],
      );
      await openPage(tester, 'About');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();

      expect(find.text('Version 1.0.4 (build 7)'), findsOneWidget);

      await tester.tap(find.text('GitHub'));
      await tester.pump();
      expect(opened.single, Uri.parse(AppConfig.githubUrl));
    });
  });
}
