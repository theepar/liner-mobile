import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liner_mobile/providers/api_provider.dart';
import 'package:liner_mobile/ui/navigation/auth_gate.dart';
import 'package:liner_mobile/ui/navigation/main_navigation_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_api.dart';

Widget _app(FakeAdapter adapter) => ProviderScope(
  overrides: [apiClientProvider.overrideWithValue(clientWith(adapter))],
  child: const MaterialApp(home: AuthGate()),
);

Future<void> _fillCredentials(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Email'),
    'me@example.com',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Password'),
    'secret',
  );
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('signed-out users only see the login page', (tester) async {
    await tester.pumpWidget(_app(FakeAdapter((_) => jsonResponse({}))));

    expect(find.text('Sign in to Liner'), findsOneWidget);
    expect(find.byType(MainNavigationShell), findsNothing);
  });

  testWidgets('empty fields are rejected before any request', (tester) async {
    final adapter = FakeAdapter((_) => jsonResponse({}));
    await tester.pumpWidget(_app(adapter));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pump();

    expect(find.text('Required'), findsWidgets);
    expect(adapter.requests, isEmpty);
  });

  testWidgets('a failed sign-in shows the message and allows retrying', (
    tester,
  ) async {
    final adapter = FakeAdapter((_) => jsonResponse({}, status: 401));
    await tester.pumpWidget(_app(adapter));

    await _fillCredentials(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Sign in'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('registration asks for a username and display name', (
    tester,
  ) async {
    await tester.pumpWidget(_app(FakeAdapter((_) => jsonResponse({}))));

    await tester.tap(find.text("Don't have an account? Create one"));
    await tester.pump();

    expect(find.text('Create your Liner account'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Username'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Display name'), findsOneWidget);
  });
}
