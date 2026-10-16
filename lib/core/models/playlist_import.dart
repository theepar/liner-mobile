import 'json_helpers.dart';
import 'track.dart';

enum ImportStatus {
  queued,
  running,
  awaitingDecision,
  finalizing,
  completed,
  failed;

  static ImportStatus parse(String? value) => switch (value) {
    'queued' => queued,
    'awaiting_decision' => awaitingDecision,
    'finalizing' => finalizing,
    'completed' => completed,
    'failed' => failed,
    _ => running,
  };

  bool get isFinished => this == completed || this == failed;
}

class ImportResult {
  const ImportResult({
    required this.total,
    required this.imported,
    required this.skipped,
  });

  static ImportResult? tryParse(Object? value) {
    final json = asMap(value);
    if (json == null) return null;
    return ImportResult(
      total: asInt(json['total']) ?? 0,
      imported: asInt(json['imported']) ?? 0,
      skipped: asInt(json['skipped']) ?? 0,
    );
  }

  final int total;
  final int imported;
  final int skipped;
}

/// A playlist import job, from `POST /v1/me/playlist-imports` and from the
/// import worker's live `job` messages.
class ImportJob {
  const ImportJob({
    required this.id,
    required this.status,
    this.source,
    this.sourceUrl,
    this.title,
    this.description,
    this.requiresDecision = false,
    this.playlistId,
    this.result,
    this.queuePosition,
    this.errorMessage,
    this.importToken,
    this.workerWsUrl,
  });

  factory ImportJob.fromJson(JsonMap json) => ImportJob(
    id: json['id']?.toString() ?? '',
    status: ImportStatus.parse(asString(json['status'])),
    source: asString(json['source']),
    sourceUrl: asString(json['sourceUrl']),
    title: asString(json['title']),
    description: asString(json['description']),
    requiresDecision: asBool(json['requiresDecision']) ?? false,
    playlistId: asString(json['playlistId']),
    result: ImportResult.tryParse(json['result']),
    queuePosition: asInt(json['queuePosition']),
    errorMessage: asString(asMap(json['error'])?['message']),
    importToken: asString(json['importToken']),
    workerWsUrl: asString(json['workerWsUrl']),
  );

  final String id;
  final ImportStatus status;
  final String? source;
  final String? sourceUrl;
  final String? title;
  final String? description;
  final bool requiresDecision;
  final String? playlistId;
  final ImportResult? result;
  final int? queuePosition;
  final String? errorMessage;
  final String? importToken;
  final String? workerWsUrl;

  /// Applies a live update from the worker, keeping what it does not resend
  /// (such as the import token).
  ImportJob mergedWith(JsonMap update) {
    final next = ImportJob.fromJson({'id': id, ...update});
    return ImportJob(
      id: id,
      status: asString(update['status']) == null ? status : next.status,
      source: next.source ?? source,
      sourceUrl: next.sourceUrl ?? sourceUrl,
      title: next.title ?? title,
      description: next.description ?? description,
      requiresDecision: next.requiresDecision,
      playlistId: next.playlistId ?? playlistId,
      result: next.result ?? result,
      queuePosition: next.queuePosition,
      errorMessage: next.errorMessage,
      importToken: importToken,
      workerWsUrl: workerWsUrl,
    );
  }

  ImportJob copyWith({ImportStatus? status, String? errorMessage}) => ImportJob(
    id: id,
    status: status ?? this.status,
    source: source,
    sourceUrl: sourceUrl,
    title: title,
    description: description,
    requiresDecision: requiresDecision,
    playlistId: playlistId,
    result: result,
    queuePosition: queuePosition,
    errorMessage: errorMessage ?? this.errorMessage,
    importToken: importToken,
    workerWsUrl: workerWsUrl,
  );
}

class ImportedTrack {
  const ImportedTrack({
    required this.title,
    this.artists = const [],
    this.album,
    this.durationMs,
    this.coverUrl,
  });

  factory ImportedTrack.fromJson(JsonMap json) => ImportedTrack(
    title: asString(json['title']) ?? 'Unknown track',
    artists: [
      for (final artist in asList(json['artists']) ?? const <Object?>[])
        if (artist is String) artist,
    ],
    album: asString(json['album']),
    durationMs: asInt(json['durationMs']),
    coverUrl: asString(json['coverUrl']),
  );

  final String title;
  final List<String> artists;
  final String? album;
  final int? durationMs;
  final String? coverUrl;

  String get artistName => artists.join(', ');
}

/// One imported track whose catalog match needs the user's decision.
class ImportReview {
  const ImportReview({
    required this.id,
    required this.source,
    required this.reason,
    required this.position,
    this.proposed,
    this.proposedJson,
    this.score,
  });

  static ImportReview? tryParse(Object? value) {
    final json = asMap(value);
    final source = asMap(json?['sourceTrack']);
    if (json == null || source == null) return null;
    final proposed = asMap(json['proposedTrack']);
    return ImportReview(
      id: json['id']?.toString() ?? '',
      source: ImportedTrack.fromJson(source),
      proposed: proposed == null ? null : Track.fromJson(proposed),
      proposedJson: proposed,
      score: json['score'] is num ? (json['score'] as num).toDouble() : null,
      reason: asString(json['reason']) ?? 'low_confidence_match',
      position: asInt(json['position']) ?? 0,
    );
  }

  final String id;
  final ImportedTrack source;
  final Track? proposed;

  /// The proposed track exactly as the API sent it; it is sent back verbatim
  /// when approved.
  final JsonMap? proposedJson;
  final double? score;
  final String reason;
  final int position;

  bool get hasProposal => proposed != null;
}

class ImportReviewDecision {
  const ImportReviewDecision({required this.reviewId, required this.approve});

  final String reviewId;
  final bool approve;

  JsonMap toJson() => {
    'reviewId': reviewId,
    'decision': approve ? 'approve' : 'deny',
  };
}

/// Reviews the user can act on: unmatched tracks and duplicates are dropped.
List<ImportReview> reviewableItems(Iterable<ImportReview> reviews) {
  final seen = <String>{};
  return [
    for (final review in reviews)
      if (review.hasProposal &&
          review.reason != 'no_catalog_candidates' &&
          seen.add(review.id.isEmpty ? '${review.position}' : review.id))
        review,
  ];
}
