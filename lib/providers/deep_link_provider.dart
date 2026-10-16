import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/deep_link.dart';
import '../services/deep_link_source.dart';

final deepLinkSourceProvider = Provider<DeepLinkSource>(
  (ref) => const PlatformDeepLinkSource(),
);

/// The latest valid link that has not been opened yet. It waits here while the
/// user is signed out, and the signed-in shell opens it and clears it.
final pendingDeepLinkProvider =
    StateNotifierProvider<PendingDeepLink, DeepLinkTarget?>(
      (ref) => PendingDeepLink(ref.watch(deepLinkSourceProvider)),
    );

class PendingDeepLink extends StateNotifier<DeepLinkTarget?> {
  PendingDeepLink(DeepLinkSource source) : super(null) {
    _subscription = source.links.listen(_accept);
  }

  late final StreamSubscription<Uri> _subscription;

  void _accept(Uri uri) {
    final target = DeepLinks.parse(uri);
    if (target != null) state = target;
  }

  void consume() => state = null;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
