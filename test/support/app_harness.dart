import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liner_mobile/main.dart';
import 'package:liner_mobile/providers/api_provider.dart';
import 'package:liner_mobile/providers/deep_link_provider.dart';
import 'package:liner_mobile/services/deep_link_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';

typedef RouteHandler = Object? Function(RequestOptions options);

class NoDeepLinks implements DeepLinkSource {
  const NoDeepLinks();

  @override
  Stream<Uri> get links => const Stream.empty();
}

Map<String, Object?> plainTrack(String id, {String? title}) => {
  'id': id,
  'title': title ?? 'Track $id',
  'artists': [
    {'id': 'ar1', 'name': 'Artist One'},
  ],
  'album': {'id': 'alb1', 'title': 'Album One'},
  'durationMs': 180000,
};

FakeAdapter fakeBackend({
  Map<String, RouteHandler> routes = const {},
  List<RequestOptions>? log,
}) {
  final defaults = <String, RouteHandler>{
    'POST /v1/auth/login': (_) => authPayload(),
    'GET /v1/explore/popular': (_) => {
      'items': [
        {'rank': 1, 'track': plainTrack('t1', title: 'Trending Song')},
      ],
    },
    'GET /v1/me/history': (_) => {'items': <Object?>[]},
    'GET /v1/me/recommendations/daily-mixes': (_) => {'items': <Object?>[]},
    'GET /v1/me/library/tracks': (_) => {'items': <Object?>[]},
    'GET /v1/me/library/artists': (_) => {'items': <Object?>[]},
    'GET /v1/me/library/albums': (_) => {'items': <Object?>[]},
    'GET /v1/me/library/playlists': (_) => {'items': <Object?>[]},
    'GET /v1/me/playlists': (_) => {'items': <Object?>[]},
  };
  return FakeAdapter((options) {
    log?.add(options);
    final key = '${options.method} ${options.path}';
    final route = routes[key] ?? defaults[key];
    if (route == null) return jsonResponse({}, status: 404);
    final body = route(options);
    return body is ResponseBody ? body : jsonResponse(body);
  });
}

Future<void> signedInApp(
  WidgetTester tester,
  FakeAdapter adapter, {
  List<Override> overrides = const [],
  Map<String, Object> preferences = const {},
  DeepLinkSource deepLinks = const NoDeepLinks(),
}) async {
  FlutterSecureStorage.setMockInitialValues({});
  SharedPreferences.setMockInitialValues(preferences);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(clientWith(adapter)),
        deepLinkSourceProvider.overrideWithValue(deepLinks),
        ...overrides,
      ],
      child: const LinerApp(),
    ),
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Email'),
    'me@example.com',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Password'),
    'password123',
  );
  await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
  await tester.pumpAndSettle();
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}
