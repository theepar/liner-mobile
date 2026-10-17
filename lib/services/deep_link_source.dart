import 'package:app_links/app_links.dart';

abstract interface class DeepLinkSource {
  Stream<Uri> get links;
}

class PlatformDeepLinkSource implements DeepLinkSource {
  const PlatformDeepLinkSource();

  @override
  Stream<Uri> get links => AppLinks().uriLinkStream;
}
