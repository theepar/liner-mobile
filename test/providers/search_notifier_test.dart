import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liner_mobile/core/api/liner_api.dart';
import 'package:liner_mobile/providers/search_provider.dart';

import '../support/fake_api.dart';

void main() {
  Map<String, Object?> results(String trackId) => {
    'items': [trackJson(trackId)..['type'] = 'track'],
  };

  test('clears results for a blank query', () async {
    final notifier = SearchNotifier(
      LinerApi(clientWith(FakeAdapter((_) => jsonResponse(results('t1'))))),
      debounce: Duration.zero,
    )..search('  ');

    expect(notifier.state.query, isEmpty);
    expect(notifier.state.isLoading, isFalse);
    notifier.dispose();
  });

  test('debounces rapid typing into a single request', () async {
    final adapter = FakeAdapter((_) => jsonResponse(results('t1')));
    final notifier = SearchNotifier(
      LinerApi(clientWith(adapter)),
      debounce: const Duration(milliseconds: 50),
    )..search('a');
    notifier
      ..search('ab')
      ..search('abc');

    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.queryParameters['q'], 'abc');
    expect(notifier.state.tracks.single.id, 't1');
    notifier.dispose();
  });

  test('ignores a slow response for a superseded query', () async {
    final slow = Completer<ResponseBody>();
    final adapter = FakeAdapter((options) {
      return options.queryParameters['q'] == 'old'
          ? slow.future
          : jsonResponse(results('new'));
    });
    final notifier = SearchNotifier(
      LinerApi(clientWith(adapter)),
      debounce: Duration.zero,
    )..search('old');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    notifier.search('new');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    slow.complete(jsonResponse(results('old')));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(notifier.state.tracks.single.id, 'new');
    notifier.dispose();
  });

  test('reports a failed search instead of showing stale results', () async {
    final notifier = SearchNotifier(
      LinerApi(clientWith(FakeAdapter((_) => jsonResponse({}, status: 500)))),
      debounce: Duration.zero,
    )..search('x');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(notifier.state.hasError, isTrue);
    expect(notifier.state.isLoading, isFalse);
    notifier.dispose();
  });
}
