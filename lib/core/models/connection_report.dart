/// The outcome of pinging the active API server's health endpoint.
class ConnectionReport {
  const ConnectionReport({
    required this.baseUrl,
    this.statusCode,
    this.latency,
    this.failure,
  });

  final String baseUrl;
  final int? statusCode;
  final Duration? latency;

  /// Why the server could not be reached, when it could not.
  final String? failure;

  bool get isReachable => statusCode == 200;
}
