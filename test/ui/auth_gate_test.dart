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
    'password123',
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

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Password must be at least 8 characters'), findsOneWidget);
    expect(adapter.requests, isEmpty);
  });

  testWidgets('a failed sign-in shows the message and allows retrying', (
    tester,
  ) async {
    final adapter = FakeAdapter(
      (_) => jsonResponse({'code': 'INVALID_CREDENTIALS'}, status: 401),
    );
    await tester.pumpWidget(_app(adapter));

    await _fillCredentials(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Email or password is incorrect.'), findsOneWidget);
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

  group('registration form', () {
    Future<void> openRegister(WidgetTester tester, FakeAdapter adapter) async {
      await tester.pumpWidget(_app(adapter));
      await tester.tap(find.text("Don't have an account? Create one"));
      await tester.pump();
    }

    Future<void> fill(WidgetTester tester, Map<String, String> fields) async {
      for (final entry in fields.entries) {
        await tester.enterText(
          find.widgetWithText(TextFormField, entry.key),
          entry.value,
        );
      }
    }

    testWidgets('asks to confirm the password', (tester) async {
      await openRegister(tester, FakeAdapter((_) => jsonResponse({})));

      expect(
        find.widgetWithText(TextFormField, 'Confirm password'),
        findsOneWidget,
      );
    });

    testWidgets('rejects mismatched passwords before any request', (
      tester,
    ) async {
      final adapter = FakeAdapter((_) => jsonResponse({}));
      await openRegister(tester, adapter);

      await fill(tester, {
        'Display name': 'Me',
        'Username': 'me_1',
        'Email': 'me@example.com',
        'Password': 'password123',
        'Confirm password': 'password124',
      });
      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
      await tester.pump();

      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(adapter.requests, isEmpty);
    });

    testWidgets('lowercases the username as it is typed', (tester) async {
      await openRegister(tester, FakeAdapter((_) => jsonResponse({})));

      await fill(tester, {'Username': 'My Name!_X'});

      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Username'),
            )
            .controller!
            .text,
        'myname_x',
      );
    });

    testWidgets('sends the normalized fields and opens the app', (
      tester,
    ) async {
      final adapter = FakeAdapter((options) {
        return options.path == '/v1/auth/register'
            ? jsonResponse(authPayload())
            : jsonResponse({'items': <Object?>[]});
      });
      await openRegister(tester, adapter);

      await fill(tester, {
        'Display name': '  Me  ',
        'Username': 'me_1',
        'Email': 'Me@Example.com',
        'Password': 'password123',
        'Confirm password': 'password123',
      });
      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
      await tester.pumpAndSettle();

      final register = adapter.requests.firstWhere(
        (r) => r.path == '/v1/auth/register',
      );
      expect(register.data, {
        'email': 'me@example.com',
        'password': 'password123',
        'username': 'me_1',
        'displayName': 'Me',
      });
      expect(find.byType(MainNavigationShell), findsOneWidget);
    });

    testWidgets('shows the server error for a taken username', (tester) async {
      final adapter = FakeAdapter(
        (_) => jsonResponse({'code': 'USERNAME_TAKEN'}, status: 409),
      );
      await openRegister(tester, adapter);

      await fill(tester, {
        'Display name': 'Me',
        'Username': 'taken',
        'Email': 'me@example.com',
        'Password': 'password123',
        'Confirm password': 'password123',
      });
      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(
        find.text('This username is already taken. Please choose another.'),
        findsOneWidget,
      );
    });
  });
}
