import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/collection_type.dart';
import '../../../core/models/playback_event.dart';
import '../../../providers/library_provider.dart';
import '../../widgets/collection_header.dart';
import '../../widgets/detail_scaffold.dart';
import '../../widgets/save_button.dart';

class CatalogPlaylistScreen extends ConsumerWidget {
  const CatalogPlaylistScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackContext = PlaybackContext.playlist(playlistId);
    return DetailScaffold(
      body: detailBody(
        ref.watch(catalogPlaylistProvider(playlistId)),
        errorMessage: "Couldn't load this playlist.",
        onRetry: () => ref.invalidate(catalogPlaylistProvider(playlistId)),
        builder: (playlist) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            CollectionHeader(
              title: playlist.title,
              coverUrl: playlist.coverUrl,
              subtitle: playlist.author,
              details:
                  '${playlist.trackCount ?? playlist.tracks.length} tracks',
              description: playlist.description,
              placeholderIcon: Icons.queue_music_rounded,
              actions: [
                PlayActions(
                  tracks: playlist.tracks,
                  playbackContext: playbackContext,
                ),
                SaveButton(type: CollectionType.playlists, id: playlist.id),
              ],
            ),
            const SizedBox(height: 8),
            TrackRows(
              tracks: playlist.tracks,
              playbackContext: playbackContext,
              showRank: true,
            ),
          ],
        ),
      ),
    );
  }
}
