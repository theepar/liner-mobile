import 'package:app_links/app_links.dart';

/// Where links that open the app come from: the launch link and any received
/// while it is running.
abstract interface class DeepLinkSource {
  Stream<Uri> get links;
}

class PlatformDeepLinkSource implements DeepLinkSource {
  const PlatformDeepLinkSource();

  @override
  Stream<Uri> get links => AppLinks().uriLinkStream;
}
