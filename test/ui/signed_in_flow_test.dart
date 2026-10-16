import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liner_mobile/providers/api_provider.dart';
import 'package:liner_mobile/ui/navigation/auth_gate.dart';
import 'package:liner_mobile/ui/navigation/main_navigation_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_api.dart';

/// Tracks without artwork keep the test off the image cache's platform plugins.
Map<String, Object?> _track(String id, String title) => {
  'id': id,
  'title': title,
  'artists': [
    {'id': 'a1', 'name': 'Artist One'},
  ],
  'durationMs': 180000,
};

FakeAdapter _backend() => FakeAdapter((options) {
  switch (options.path) {
    case '/v1/auth/login':
      return jsonResponse(authPayload());
    case '/v1/explore/popular':
      return jsonResponse({
        'items': [
          {'rank': 1, 'track': _track('t1', 'Trending Song'), 'playCount': 9},
        ],
      });
    case '/v1/me/history':
      return jsonResponse({
        'items': [
          {'track': _track('t2', 'Recent Song')},
        ],
        'nextCursor': null,
      });
    case '/v1/me/recommendations/daily-mixes':
      return jsonResponse({
        'items': [
          {
            'id': 'mix1',
            'title': 'Daily Mix 1',
            'description': 'Chill vibes',
            'trackCount': 1,
            'tracks': [_track('t3', 'Mix Song')],
          },
        ],
      });
    case '/v1/me/library/tracks':
      return jsonResponse({
        'items': [
          {'track': _track('t1', 'Trending Song'), 'likedAt': 'x'},
        ],
        'nextCursor': null,
      });
    case '/v1/me/playlists':
      return jsonResponse({
        'items': [
          {'id': 'p1', 'title': 'My Playlist', 'isPublic': false},
        ],
      });
    case '/v1/me/library/artists':
      return jsonResponse({
        'items': [
          {'id': 'ar1', 'name': 'Followed Artist'},
        ],
      });
    case '/v1/search':
      return jsonResponse({
        'items': [
          {'type': 'track', ..._track('t9', 'Found Song')},
        ],
      });
  }
  return jsonResponse({}, status: 404);
});

Future<void> _signIn(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(clientWith(_backend()))],
      child: const MaterialApp(home: AuthGate()),
    ),
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Email'),
    'me@example.com',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Password'),
    'secret',
  );
  await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('signing in opens the app with live data on Home', (
    tester,
  ) async {
    await _signIn(tester);

    expect(find.byType(MainNavigationShell), findsOneWidget);
    expect(find.text('Recent Song'), findsOneWidget);
    expect(find.text('Daily Mix 1'), findsOneWidget);
    expect(find.text('Popular Artists'), findsNothing);

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
    expect(find.text('Trending Song'), findsOneWidget);
  });

  testWidgets('Library lists the account playlists, artists and likes', (
    tester,
  ) async {
    await _signIn(tester);

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();

    expect(find.text('1 liked track'), findsOneWidget);
    expect(find.text('My Playlist'), findsOneWidget);
    expect(find.text('Followed Artist'), findsOneWidget);
  });

  testWidgets('Search shows results parsed from the API', (tester) async {
    await _signIn(tester);

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'found');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Found Song'), findsOneWidget);
  });

  testWidgets('signing out returns to the login page', (tester) async {
    await _signIn(tester);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to Liner'), findsOneWidget);
    expect(find.byType(MainNavigationShell), findsNothing);
  });
}
