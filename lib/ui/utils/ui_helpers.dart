import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/models/collection_type.dart';
import '../../core/models/playback_event.dart';
import '../../core/models/track.dart';
import '../../providers/api_provider.dart';
import '../../providers/app_info_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
}

void playTapped(
  BuildContext context,
  WidgetRef ref,
  Track track, {
  List<Track>? queue,
  int? index,
  PlaybackContext? playbackContext,
}) {
  final player = ref.read(playerStateProvider.notifier);
  final queueInstead =
      ref.read(settingsProvider).trackTapAction == TrackTapAction.queue &&
      ref.read(playerStateProvider).currentTrack != null;
  if (queueInstead) {
    player.addToQueue(track);
    showMessage(context, 'Added to queue');
    return;
  }
  unawaited(player.playTrack(track, queue, index, playbackContext));
}

Future<void> openExternalLink(
  BuildContext context,
  WidgetRef ref,
  String url,
) async {
  final opened = await ref.read(linkLauncherProvider)(Uri.parse(url));
  if (!opened && context.mounted) {
    showMessage(context, 'Could not open the link.');
  }
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

Future<void> toggleSaved(
  BuildContext context,
  WidgetRef ref,
  CollectionType type,
  String id,
) async {
  final api = ref.read(linerApiProvider);
  final isSaved = ref.read(savedIdsProvider(type)).contains(id);
  try {
    if (isSaved) {
      await api.removeCollection(type, id);
    } else {
      await api.saveCollection(type, id);
    }
  } on ApiException {
    if (context.mounted) {
      showMessage(context, 'Could not update your library.');
    }
    return;
  }
  switch (type) {
    case CollectionType.albums:
      ref.invalidate(savedAlbumsProvider);
    case CollectionType.artists:
      ref.invalidate(followedArtistsProvider);
    case CollectionType.playlists:
      ref.invalidate(savedPlaylistsProvider);
  }
}
