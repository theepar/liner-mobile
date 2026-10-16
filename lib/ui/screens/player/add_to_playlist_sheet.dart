import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/track.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/api_provider.dart';
import '../../../providers/library_provider.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/status_views.dart';
import '../library/create_playlist_sheet.dart';

Future<void> showAddToPlaylistSheet(BuildContext context, Track track) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: LinerColors.darkElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _AddToPlaylistSheet(track: track),
  );
}

class _AddToPlaylistSheet extends ConsumerWidget {
  const _AddToPlaylistSheet({required this.track});

  final Track track;

  Future<void> _add(BuildContext context, WidgetRef ref, String id) async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    try {
      await ref.read(linerApiProvider).addTrackToPlaylist(id, track.id);
      ref.invalidate(userPlaylistProvider(id));
      messenger.showSnackBar(
        const SnackBar(content: Text('Added to playlist')),
      );
    } on ApiException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error.statusCode == 409
                ? 'Already in that playlist'
                : 'Could not add the track.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(userPlaylistsProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      builder: (context, controller) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'Add to playlist',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: LinerColors.accentPrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: LinerColors.accentPrimary,
              ),
            ),
            title: const Text(
              'New playlist',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () async {
              final navigator = Navigator.of(context);
              final sheetContext = navigator.context;
              navigator.pop();
              if (sheetContext.mounted) {
                await showCreatePlaylistSheet(
                  sheetContext,
                  pendingTrack: track,
                );
              }
            },
          ),
          Expanded(
            child: playlists.when(
              loading: () => const LoadingView(),
              error: (_, _) => ErrorRetry(
                message: "Couldn't load your playlists.",
                onRetry: () => ref.invalidate(userPlaylistsProvider),
              ),
              data: (items) => ListView.builder(
                controller: controller,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final playlist = items[index];
                  return ListTile(
                    leading: const Icon(
                      Icons.queue_music_rounded,
                      color: Colors.white54,
                    ),
                    title: Text(
                      playlist.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () => _add(context, ref, playlist.id),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when a playlist could not be changed.
void showPlaylistError(BuildContext context) =>
    showMessage(context, 'Could not update the playlist.');
