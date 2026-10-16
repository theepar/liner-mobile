import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/album.dart';
import '../../../core/models/collection_type.dart';
import '../../../core/models/playback_event.dart';
import '../../../providers/library_provider.dart';
import '../../widgets/collection_header.dart';
import '../../widgets/detail_scaffold.dart';
import '../../widgets/save_button.dart';

class AlbumScreen extends ConsumerWidget {
  const AlbumScreen({super.key, required this.albumId});

  final String albumId;

  static String _details(Album album) => [
    if (album.year != null) '${album.year}',
    '${album.trackCount ?? album.tracks.length} tracks',
    if (album.durationMs != null && album.durationMs! > 0)
      '${(album.durationMs! / 60000).round()} min',
  ].join(' • ');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final context_ = PlaybackContext('album', albumId);
    return DetailScaffold(
      body: detailBody(
        ref.watch(albumProvider(albumId)),
        errorMessage: "Couldn't load this album.",
        onRetry: () => ref.invalidate(albumProvider(albumId)),
        builder: (album) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            CollectionHeader(
              title: album.title,
              coverUrl: album.coverUrl,
              subtitle: album.artistName.isEmpty ? null : album.artistName,
              details: _details(album),
              actions: [
                PlayActions(tracks: album.tracks, playbackContext: context_),
                SaveButton(type: CollectionType.albums, id: album.id),
              ],
            ),
            const SizedBox(height: 8),
            TrackRows(
              tracks: album.tracks,
              playbackContext: context_,
              showRank: true,
            ),
          ],
        ),
      ),
    );
  }
}
