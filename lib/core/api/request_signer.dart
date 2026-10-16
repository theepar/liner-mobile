/// Produces the headers the Liner API gateway requires on `/v1/*` requests:
/// `x-liner-signature`, `x-liner-timestamp` and `x-liner-nonce`.
///
/// The official signer is not part of this repository. Install an authorized
/// implementation with `ApiClient.instance.signer = ...` before `runApp`.
abstract interface class RequestSigner {
  /// [path] has no query string; [timestamp] is in server-adjusted seconds;
  /// [body] is exactly the JSON string that will be sent, or null.
  Future<Map<String, String>> sign({
    required String method,
    required String path,
    required int timestamp,
    String? body,
  });
}
