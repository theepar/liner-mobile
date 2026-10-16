import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liner_mobile/core/api/api_client.dart';
import 'package:liner_mobile/core/api/liner_api.dart';
import 'package:liner_mobile/core/models/playlist_import.dart';
import 'package:liner_mobile/providers/import_provider.dart';
import 'package:liner_mobile/services/import_worker_connection.dart';

import '../support/fake_api.dart';

class _FakeConnection implements WorkerConnection {
  final controller = StreamController<String>();
  var closed = false;

  @override
  Stream<String> get messages => controller.stream;

  @override
  Future<void> close() async {
    closed = true;
    await controller.close();
  }

  void send(Map<String, Object?> message) =>
      controller.add(jsonEncode(message));
}

Map<String, Object?> _job(
  String status, {
  String? playlistId,
  bool withToken = true,
  Map<String, Object?> extra = const {},
}) => {
  'id': 'j1',
  'source': 'spotify',
  'sourceUrl': 'https://open.spotify.com/playlist/abc',
  'title': 'Road trip',
  'status': status,
  'playlistId': ?playlistId,
  if (withToken) 'importToken': 'tok',
  ...extra,
};

Map<String, Object?> _review(
  String id, {
  String reason = 'low_confidence_match',
  bool proposed = true,
}) => {
  'id': id,
  'sourceTrack': {
    'sourceId': 's$id',
    'title': 'Source $id',
    'artists': ['Artist'],
    'durationMs': 180000,
  },
  if (proposed) 'proposedTrack': trackJson('t$id'),
  'reason': reason,
  'status': 'pending',
  'position': int.parse(id),
};

void main() {
  late List<RequestOptions> requests;
  late _FakeConnection connection;
  late List<Uri> connectedTo;
  late int libraryChanges;
  late Map<String, Object?> Function() statusBody;
  late Object? Function() reviewBody;
  late Map<String, Object?> Function() createBody;
  late bool failCreate;

  ImportController build({bool connectFails = false}) {
    final adapter = FakeAdapter((options) {
      requests.add(options);
      if (options.method == 'POST' &&
          options.path == '/v1/me/playlist-imports') {
        return failCreate
            ? jsonResponse({'code': 'INVALID_INPUT'}, status: 400)
            : jsonResponse(createBody());
      }
      if (options.method == 'GET' && options.path.endsWith('/review')) {
        return jsonResponse(reviewBody());
      }
      if (options.method == 'POST' && options.path.endsWith('/review')) {
        return jsonResponse({'approved': <Object?>[], 'finalized': true});
      }
      return jsonResponse(statusBody());
    });
    return ImportController(
      LinerApi(clientWith(adapter)),
      onLibraryChanged: () => libraryChanges++,
      pollInterval: const Duration(milliseconds: 10),
      connector: (uri) async {
        connectedTo.add(uri);
        if (connectFails) throw const FormatException('offline');
        return connection;
      },
    );
  }

  setUp(() {
    requests = [];
    connection = _FakeConnection();
    connectedTo = [];
    libraryChanges = 0;
    failCreate = false;
    createBody = () => _job('queued');
    statusBody = () => _job('running');
    reviewBody = () => {'items': <Object?>[]};
  });

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 60));

  test(
    'a job that is already completed refreshes the library right away',
    () async {
      createBody = () => _job('completed', playlistId: 'p1', withToken: false);
      final controller = build();

      await controller.start('https://soundcloud.com/me/likes');

      expect(controller.state.job?.status, ImportStatus.completed);
      expect(libraryChanges, 1);
      expect(connectedTo, isEmpty);
      controller.dispose();
    },
  );

  test('follows the worker connection through to completion', () async {
    final controller = build();
    await controller.start('https://open.spotify.com/playlist/abc');

    expect(
      connectedTo.single.toString(),
      'wss://import.tryliner.fun/v1/ws?token=tok',
    );
    expect(controller.state.isRunning, isTrue);

    connection.send({'type': 'job', 'status': 'running', 'queuePosition': 2});
    await settle();
    expect(controller.state.job?.status, ImportStatus.running);
    expect(controller.state.job?.queuePosition, 2);
    expect(controller.state.job?.title, 'Road trip');

    connection.send({
      'type': 'job',
      'status': 'completed',
      'playlistId': 'p9',
      'result': {'total': 10, 'imported': 8, 'skipped': 2},
    });
    await settle();

    expect(controller.state.job?.status, ImportStatus.completed);
    expect(controller.state.job?.playlistId, 'p9');
    expect(controller.state.job?.result?.imported, 8);
    expect(connection.closed, isTrue);
    expect(libraryChanges, 1);
    controller.dispose();
  });

  test('uses the worker address supplied by the server', () async {
    createBody = () =>
        _job('queued', extra: {'workerWsUrl': 'https://worker.example/ws?v=1'});
    final controller = build();

    await controller.start('https://music.youtube.com/playlist?list=x');

    expect(
      connectedTo.single.toString(),
      'wss://worker.example/ws?v=1&token=tok',
    );
    controller.dispose();
  });

  test('an unsupported worker address falls back to polling', () async {
    createBody = () =>
        _job('queued', extra: {'workerWsUrl': 'ftp://worker.example'});
    statusBody = () => _job('completed', playlistId: 'p2');
    final controller = build();

    await controller.start('https://deezer.com/playlist/1');
    await settle();

    expect(connectedTo, isEmpty);
    expect(controller.state.job?.status, ImportStatus.completed);
    controller.dispose();
  });

  test('polls when the job carries no worker token', () async {
    createBody = () => _job('queued', withToken: false);
    var calls = 0;
    statusBody = () =>
        ++calls < 3 ? _job('running') : _job('completed', playlistId: 'p3');
    final controller = build();

    await controller.start('https://soundcloud.com/me/sets/x');
    await settle();
    await settle();

    expect(connectedTo, isEmpty);
    expect(controller.state.job?.status, ImportStatus.completed);
    expect(libraryChanges, 1);
    controller.dispose();
  });

  test('a dropped worker connection falls back to polling', () async {
    statusBody = () => _job('completed', playlistId: 'p4');
    final controller = build();
    await controller.start('https://open.spotify.com/playlist/abc');

    await connection.controller.close();
    await settle();

    expect(controller.state.job?.status, ImportStatus.completed);
    controller.dispose();
  });

  test('a failed job exposes the worker error', () async {
    final controller = build();
    await controller.start('https://open.spotify.com/playlist/abc');

    connection.send({
      'type': 'job',
      'status': 'failed',
      'error': {'code': 'PRIVATE', 'message': 'Playlist is private'},
    });
    await settle();

    expect(controller.state.error, 'Playlist is private');
    expect(controller.state.isRunning, isFalse);
    controller.dispose();
  });

  test('reports a rejected link and leaves no job behind', () async {
    failCreate = true;
    final controller = build();

    await expectLater(
      controller.start('https://example.com/not-a-playlist'),
      throwsA(isA<ApiException>()),
    );

    expect(controller.state.job, isNull);
    expect(controller.state.isStarting, isFalse);
    controller.dispose();
  });

  group('review', () {
    Future<ImportController> awaitingDecision() async {
      final controller = build();
      await controller.start('https://open.spotify.com/playlist/abc');
      connection.send({
        'type': 'job',
        'status': 'awaiting_decision',
        'requiresDecision': true,
        'reviewItems': [
          _review('1'),
          _review('2'),
          _review('2'),
          _review('3', reason: 'no_catalog_candidates', proposed: false),
        ],
        'approvedTracks': [trackJson('auto1')],
      });
      await settle();
      return controller;
    }

    test('only actionable, unique items are offered', () async {
      final controller = await awaitingDecision();

      final items = await controller.loadReviews();

      expect(items.map((i) => i.id), ['1', '2']);
      expect(controller.state.job?.status, ImportStatus.awaitingDecision);
      expect(connection.closed, isTrue);
      controller.dispose();
    });

    test('submits decisions with auto-matched and approved tracks', () async {
      final controller = await awaitingDecision();
      final items = await controller.loadReviews();
      statusBody = () => _job('completed', playlistId: 'p5');

      await controller.submitReview(items, {'1': true, '2': false});

      final post = requests.lastWhere(
        (r) => r.method == 'POST' && r.path.endsWith('/review'),
      );
      final body = post.data as Map<String, Object?>;
      expect(body['decisions'], [
        {'reviewId': '1', 'decision': 'approve'},
        {'reviewId': '2', 'decision': 'deny'},
      ]);
      expect((body['tracks'] as List<Object?>).length, 2);
      expect(
        ((body['tracks'] as List<Object?>).first as Map<String, Object?>)['id'],
        'auto1',
      );
      expect(body['title'], 'Road trip');
      expect(controller.state.job?.status, ImportStatus.completed);
      expect(libraryChanges, 1);
      controller.dispose();
    });

    test('skipping keeps only the automatic matches', () async {
      final controller = await awaitingDecision();
      statusBody = () => _job('completed', playlistId: 'p6');

      await controller.skipReview();

      final post = requests.lastWhere(
        (r) => r.method == 'POST' && r.path.endsWith('/review'),
      );
      final body = post.data as Map<String, Object?>;
      expect(body['action'], 'skip');
      expect((body['tracks'] as List<Object?>).length, 1);
      expect(libraryChanges, 1);
      controller.dispose();
    });

    test(
      'keeps following the job until the server reports completion',
      () async {
        final controller = await awaitingDecision();
        final items = await controller.loadReviews();
        var calls = 0;
        statusBody = () => ++calls < 3
            ? _job('finalizing')
            : _job('completed', playlistId: 'p7');

        await controller.submitReview(items, {'1': true});
        expect(controller.state.job?.status, ImportStatus.finalizing);
        expect(libraryChanges, 0);

        await settle();
        await settle();

        expect(controller.state.job?.status, ImportStatus.completed);
        expect(libraryChanges, 1);
        controller.dispose();
      },
    );

    test('fetches reviews from the API when the worker sent none', () async {
      reviewBody = () => {
        'items': [_review('1')],
      };
      final controller = build();
      await controller.start('https://open.spotify.com/playlist/abc');
      connection.send({'type': 'job', 'status': 'awaiting_decision'});
      await settle();

      final items = await controller.loadReviews();

      expect(items.single.id, '1');
      controller.dispose();
    });
  });

  test('dismissing clears the job and stops listening', () async {
    final controller = build();
    await controller.start('https://open.spotify.com/playlist/abc');

    controller.dismiss();
    await settle();

    expect(controller.state.job, isNull);
    expect(connection.closed, isTrue);
    controller.dispose();
  });
}
