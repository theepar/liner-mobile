import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liner_mobile/core/api/api_client.dart';

typedef RequestHandler =
    FutureOr<ResponseBody> Function(RequestOptions options);

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final RequestHandler handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object? body, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

ResponseBody sseResponse(List<Object> events) => ResponseBody(
  Stream.value(
    Uint8List.fromList(
      utf8.encode(events.map((e) => 'data: ${jsonEncode(e)}\n\n').join()),
    ),
  ),
  200,
  headers: {
    Headers.contentTypeHeader: ['text/event-stream'],
  },
);

ApiClient clientWith(FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = adapter;
  return ApiClient.withDio(dio);
}

Map<String, Object?> trackJson(String id, {String title = 'Song'}) => {
  'id': id,
  'title': title,
  'artists': [
    {'id': 'a1', 'name': 'Artist One'},
  ],
  'album': {'id': 'al1', 'title': 'Album'},
  'durationMs': 180000,
  'cover': {'url': 'https://img/$id.jpg', 'fallbackUrl': 'https://fb/$id.jpg'},
  'explicit': false,
};

Map<String, Object?> authPayload({
  String access = 'access-1',
  String refresh = 'refresh-1',
}) => {
  'accessToken': access,
  'refreshToken': refresh,
  'accessTokenExpiresAt': DateTime.now()
      .add(const Duration(hours: 1))
      .toUtc()
      .toIso8601String(),
  'user': {'id': 'u1', 'email': 'me@example.com', 'username': 'me'},
};

void expectAuthorization(RequestOptions options, String? expected) {
  expect(options.headers['Authorization'], expected);
}
