import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/models/track.dart';
import '../../providers/library_provider.dart';

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
}

Future<void> toggleLike(
  BuildContext context,
  WidgetRef ref,
  Track track,
) async {
  try {
    await ref.read(likedTracksProvider.notifier).toggle(track);
  } on ApiException {
    if (context.mounted) {
      showMessage(context, 'Could not update your liked songs.');
    }
  }
}
