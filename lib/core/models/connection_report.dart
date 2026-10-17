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

  final String? failure;

  bool get isReachable => statusCode == 200;
}
