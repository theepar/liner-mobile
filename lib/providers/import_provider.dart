import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/api/liner_api.dart';
import '../core/config/app_config.dart';
import '../core/models/json_helpers.dart';
import '../core/models/playlist_import.dart';
import '../services/import_worker_connection.dart';
import 'api_provider.dart';
import 'library_provider.dart';

final importControllerProvider =
    StateNotifierProvider<ImportController, ImportState>((ref) {
      void libraryChanged() {
        ref
          ..invalidate(userPlaylistsProvider)
          ..invalidate(likedTracksProvider);
      }

      return ImportController(
        ref.watch(linerApiProvider),
        onLibraryChanged: libraryChanged,
      );
    });

class ImportState {
  const ImportState({
    this.job,
    this.isStarting = false,
    this.error,
    this.reviews,
    this.approvedTracks = const [],
  });

  final ImportJob? job;
  final bool isStarting;
  final String? error;

  /// Reviews delivered with the worker's updates, if any.
  final List<ImportReview>? reviews;

  /// Tracks the importer already matched with confidence, sent back verbatim
  /// when the review is submitted.
  final List<JsonMap> approvedTracks;

  bool get isRunning =>
      isStarting || (job != null && !job!.status.isFinished && error == null);

  ImportState copyWith({
    ImportJob? job,
    bool? isStarting,
    String? error,
    bool clearError = false,
    List<ImportReview>? reviews,
    bool clearReviews = false,
    List<JsonMap>? approvedTracks,
  }) => ImportState(
    job: job ?? this.job,
    isStarting: isStarting ?? this.isStarting,
    error: clearError ? null : (error ?? this.error),
    reviews: clearReviews ? null : (reviews ?? this.reviews),
    approvedTracks: approvedTracks ?? this.approvedTracks,
  );
}

/// Runs one playlist import at a time: creates the job, follows its progress
/// on the import worker (falling back to polling) and handles the review step.
class ImportController extends StateNotifier<ImportState> {
  ImportController(
    this._api, {
    required this.onLibraryChanged,
    WorkerConnector connector = connectToImportWorker,
    this.pollInterval = const Duration(seconds: 1),
    this.maxPolls = 900,
  }) : _connector = connector,
       super(const ImportState());

  final LinerApi _api;
  final void Function() onLibraryChanged;
  final WorkerConnector _connector;
  final Duration pollInterval;
  final int maxPolls;

  WorkerConnection? _connection;
  StreamSubscription<String>? _messages;
  Timer? _pollTimer;
  int _polls = 0;

  /// Throws [ApiException] if the job cannot be created.
  Future<void> start(String url) async {
    await _stopWork();
    state = const ImportState(isStarting: true);

    final ImportJob job;
    try {
      job = await _api.createPlaylistImport(url);
    } on ApiException {
      if (mounted) state = const ImportState();
      rethrow;
    }
    if (!mounted) return;
    state = ImportState(job: job);

    if (job.status == ImportStatus.completed) {
      onLibraryChanged();
      return;
    }
    final token = job.importToken;
    if (token != null && token.isNotEmpty) {
      await _listen(job, token);
    } else {
      _schedulePoll(job.id);
    }
  }

  /// The reviews the user can act on, fetched if the worker did not send them.
  Future<List<ImportReview>> loadReviews() async {
    final job = state.job;
    if (job == null) return const [];

    var items = reviewableItems(state.reviews ?? const []);
    for (var attempt = 0; items.isEmpty && attempt < 6; attempt++) {
      try {
        items = reviewableItems(await _api.getPlaylistImportReview(job.id));
      } on ApiException catch (error) {
        developer.log('review fetch failed: $error', name: 'Import');
      }
      if (items.isEmpty && attempt < 5) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    }

    if (items.isEmpty &&
        state.approvedTracks.isNotEmpty &&
        state.job?.status == ImportStatus.awaitingDecision) {
      await skipReview();
    }
    return items;
  }

  Future<void> submitReview(
    List<ImportReview> items,
    Map<String, bool> approvals,
  ) async {
    final job = state.job;
    if (job == null) return;
    final finalized = await _api.decidePlaylistImportReview(
      job.id,
      decisions: [
        for (final item in items)
          ImportReviewDecision(
            reviewId: item.id,
            approve: approvals[item.id] ?? false,
          ),
      ],
      approvedTracks: [
        ...state.approvedTracks,
        for (final item in items)
          if ((approvals[item.id] ?? false) && item.proposedJson != null)
            item.proposedJson!,
      ],
      title: job.title,
      description: job.description,
    );
    await _afterReview(job.id, finalized: finalized);
  }

  /// Finishes the import keeping only the automatically matched tracks.
  Future<void> skipReview() async {
    final job = state.job;
    if (job == null) return;
    final finalized = await _api.skipPlaylistImportReview(
      job.id,
      approvedTracks: state.approvedTracks,
      title: job.title,
      description: job.description,
    );
    await _afterReview(job.id, finalized: finalized);
  }

  void dismiss() {
    unawaited(_stopWork());
    state = const ImportState();
  }

  Future<void> _afterReview(String jobId, {required bool finalized}) async {
    ImportJob? latest;
    try {
      latest = await _api.getPlaylistImport(jobId);
    } on ApiException catch (error) {
      developer.log('import status failed: $error', name: 'Import');
    }
    if (!mounted) return;

    final fallback = finalized
        ? state.job?.copyWith(status: ImportStatus.finalizing)
        : state.job;
    state = state.copyWith(
      job: latest ?? fallback,
      clearReviews: true,
      approvedTracks: const [],
    );
    if (latest?.status == ImportStatus.completed) {
      onLibraryChanged();
    } else {
      _schedulePoll(jobId);
    }
  }

  Future<void> _listen(ImportJob job, String token) async {
    final uri = _workerUri(job.workerWsUrl, token);
    if (uri == null) {
      _schedulePoll(job.id);
      return;
    }
    try {
      final connection = await _connector(uri);
      if (!mounted) {
        unawaited(connection.close());
        return;
      }
      _connection = connection;
      _messages = connection.messages.listen(
        _onMessage,
        onError: (Object error) => _fallBackToPolling(job.id),
        onDone: () => _fallBackToPolling(job.id),
      );
    } on Exception catch (error) {
      developer.log('worker connection failed: $error', name: 'Import');
      _schedulePoll(job.id);
    }
  }

  static Uri? _workerUri(String? configured, String token) {
    final base = Uri.tryParse(
      configured == null || configured.trim().isEmpty
          ? AppConfig.importWorkerUrl
          : configured.trim(),
    );
    if (base == null || base.host.isEmpty) return null;
    final scheme = switch (base.scheme) {
      'https' || 'wss' => 'wss',
      'http' || 'ws' => 'ws',
      _ => null,
    };
    if (scheme == null) return null;
    return base.replace(
      scheme: scheme,
      queryParameters: {...base.queryParameters, 'token': token},
    );
  }

  void _onMessage(String raw) {
    if (!mounted) return;
    final message = asMap(_tryDecode(raw));
    if (message == null || message['type'] != 'job') return;

    final job = state.job?.mergedWith(message) ?? ImportJob.fromJson(message);
    final reviews = [
      for (final item in asList(message['reviewItems']) ?? const <Object?>[])
        ?ImportReview.tryParse(item),
    ];
    final approved = [
      for (final item in asList(message['approvedTracks']) ?? const <Object?>[])
        ?asMap(item),
    ];
    state = state.copyWith(
      job: job,
      reviews: reviews.isEmpty ? null : reviews,
      approvedTracks: approved.isEmpty ? null : approved,
    );

    switch (job.status) {
      case ImportStatus.awaitingDecision:
        unawaited(_closeConnection());
      case ImportStatus.completed:
        unawaited(_closeConnection());
        unawaited(_syncCompleted(job));
      case ImportStatus.failed:
        unawaited(_closeConnection());
        state = state.copyWith(error: job.errorMessage ?? 'Import failed');
      case ImportStatus.queued ||
          ImportStatus.running ||
          ImportStatus.finalizing:
        break;
    }
  }

  /// The playlist id can arrive after completion; wait for it briefly.
  Future<void> _syncCompleted(ImportJob job) async {
    var latest = job;
    for (
      var attempt = 0;
      latest.playlistId == null && attempt < 20;
      attempt++
    ) {
      try {
        latest = await _api.getPlaylistImport(job.id);
      } on ApiException {
        // Retry below.
      }
      if (latest.playlistId == null) {
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }
      if (!mounted) return;
    }
    if (!mounted) return;
    state = state.copyWith(job: latest);
    onLibraryChanged();
  }

  void _fallBackToPolling(String jobId) {
    if (!mounted) return;
    final status = state.job?.status;
    if (status == null || status.isFinished) return;
    if (status == ImportStatus.awaitingDecision) return;
    unawaited(_closeConnection());
    _schedulePoll(jobId);
  }

  void _schedulePoll(String jobId, {Duration? after}) {
    _pollTimer?.cancel();
    _pollTimer = Timer(after ?? pollInterval, () => unawaited(_poll(jobId)));
  }

  Future<void> _poll(String jobId) async {
    if (!mounted) return;
    if (++_polls > maxPolls) {
      state = state.copyWith(error: 'The import is taking too long.');
      return;
    }
    try {
      final job = await _api.getPlaylistImport(jobId);
      if (!mounted) return;
      state = state.copyWith(job: job);
      switch (job.status) {
        case ImportStatus.awaitingDecision:
          return;
        case ImportStatus.completed:
          onLibraryChanged();
          return;
        case ImportStatus.failed:
          state = state.copyWith(error: job.errorMessage ?? 'Import failed');
          return;
        case ImportStatus.queued ||
            ImportStatus.running ||
            ImportStatus.finalizing:
          _schedulePoll(jobId);
      }
    } on ApiException {
      _schedulePoll(jobId, after: pollInterval * 2.5);
    }
  }

  Future<void> _closeConnection() async {
    final connection = _connection;
    await _messages?.cancel();
    _messages = null;
    _connection = null;
    await connection?.close();
  }

  Future<void> _stopWork() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    _polls = 0;
    await _closeConnection();
  }

  static Object? _tryDecode(String payload) {
    try {
      return jsonDecode(payload);
    } on FormatException {
      return null;
    }
  }

  @override
  void dispose() {
    unawaited(_stopWork());
    super.dispose();
  }
}
