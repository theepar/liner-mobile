abstract final class AppConfig {
  static const primaryApiUrl = 'https://api.tryliner.fun';
  static const fallbackApiUrl = 'http://edge.tryliner.fun:10518';
  static const importWorkerUrl = 'wss://import.tryliner.fun/v1/ws';
  static const shareBaseUrl = 'https://link.tryliner.fun';
  static const deepLinkScheme = 'liner';

  static const channelUrl = 'https://t.me/liner_app';
  static const supportUrl = 'https://t.me/liner_app?direct';
  static const githubUrl = 'https://github.com/tryliner/desktop';
  static const websiteUrl = 'https://tryliner.fun';
  static const docsUrl =
      'https://github.com/tryliner/desktop/blob/main/README.md';

  /// Must match the `version` in pubspec.yaml (enforced by a unit test).
  static const clientVersion = '1.0.4';
  static const clientPlatform = 'flutter-mobile';

  static const _customApiUrlDefine = String.fromEnvironment('LINER_API_URL');

  /// Another Liner instance supplied with `--dart-define=LINER_API_URL=...`;
  /// empty when running against production.
  static final customApiUrl = _normalizeCustomUrl(_customApiUrlDefine);

  static bool get hasCustomApiUrl => customApiUrl.isNotEmpty;

  static String get initialApiUrl =>
      hasCustomApiUrl ? customApiUrl : primaryApiUrl;

  static String _normalizeCustomUrl(String value) {
    final url = value.trim().replaceAll(RegExp(r'/+$'), '');
    return url == primaryApiUrl || url == fallbackApiUrl ? '' : url;
  }

  static const connectTimeout = Duration(seconds: 8);
  static const receiveTimeout = Duration(seconds: 15);
  static const probeTimeout = Duration(seconds: 4);

  static String shareUrl(String type, String id) =>
      '$shareBaseUrl/$type?id=${Uri.encodeQueryComponent(id)}';

  static String deepLink(String type, String id) =>
      '$deepLinkScheme://$type?id=${Uri.encodeQueryComponent(id)}';
}
