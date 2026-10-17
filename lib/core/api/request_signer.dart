abstract interface class RequestSigner {
  Future<Map<String, String>> sign({
    required String method,
    required String path,
    required int timestamp,
    String? body,
  });
}
