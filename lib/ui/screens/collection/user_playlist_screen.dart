import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/playback_event.dart';
import '../../../core/models/playlist.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/import_source.dart';
import '../../../providers/api_provider.dart';
import '../../../providers/library_provider.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/collection_header.dart';
import '../../widgets/dark_input.dart';
import '../../widgets/detail_scaffold.dart';
import '../../widgets/status_views.dart';
import '../../widgets/track_action.dart';

enum _PlaylistMenu { edit, delete }

/// One of the user's own playlists, which can be renamed, emptied and deleted.
class UserPlaylistScreen extends ConsumerWidget {
  const UserPlaylistScreen({super.key, required this.playlistId});

  final String playlistId;

  void _refresh(WidgetRef ref) {
    ref
      ..invalidate(userPlaylistProvider(playlistId))
      ..invalidate(userPlaylistsProvider);
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
  ) async {
    final edited = await showDialog<({String title, String description})>(
      context: context,
      builder: (_) => _EditPlaylistDialog(playlist: playlist),
    );
    if (edited == null || !context.mounted) return;
    try {
      await ref
          .read(linerApiProvider)
          .updatePlaylist(
            playlist.id,
            title: edited.title,
            description: edited.description,
          );
      _refresh(ref);
    } on ApiException {
      if (context.mounted) {
        showMessage(context, 'Could not update the playlist.');
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: LinerColors.darkElevated,
        title: const Text(
          'Delete playlist?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '"${playlist.title}" will be removed from your library.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white60),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final navigator = Navigator.of(context);
    try {
      await ref.read(linerApiProvider).deletePlaylist(playlist.id);
      ref.invalidate(userPlaylistsProvider);
      navigator.pop();
    } on ApiException {
      if (context.mounted) {
        showMessage(context, 'Could not delete the playlist.');
      }
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    PlaylistItem item,
  ) async {
    try {
      await ref.read(linerApiProvider).removePlaylistItem(playlistId, item.id);
      _refresh(ref);
    } on ApiException {
      if (context.mounted) showMessage(context, 'Could not remove the track.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(userPlaylistProvider(playlistId));
    final playbackContext = PlaybackContext.playlist(playlistId);

    return DetailScaffold(
      actions: [
        if (details.valueOrNull case final loaded?)
          PopupMenuButton<_PlaylistMenu>(
            color: LinerColors.darkElevated,
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (choice) => switch (choice) {
              _PlaylistMenu.edit => _edit(context, ref, loaded.playlist),
              _PlaylistMenu.delete => _delete(context, ref, loaded.playlist),
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _PlaylistMenu.edit,
                child: Text(
                  'Edit details',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              PopupMenuItem(
                value: _PlaylistMenu.delete,
                child: Text(
                  'Delete playlist',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
      ],
      body: detailBody(
        details,
        errorMessage: "Couldn't load this playlist.",
        onRetry: () => ref.invalidate(userPlaylistProvider(playlistId)),
        builder: (loaded) {
          final tracks = loaded.tracks;
          final cover = tracks.isEmpty ? null : tracks.first;
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              CollectionHeader(
                title: loaded.playlist.title,
                coverUrl: cover?.coverUrl ?? '',
                coverFallbackUrl: cover?.coverFallbackUrl,
                details:
                    '${tracks.length} ${tracks.length == 1 ? 'track' : 'tracks'}',
                description: loaded.playlist.description,
                placeholderIcon: Icons.queue_music_rounded,
                actions: [
                  PlayActions(tracks: tracks, playbackContext: playbackContext),
                ],
              ),
              const SizedBox(height: 8),
              if (tracks.isEmpty)
                const EmptyView(
                  icon: Icons.queue_music_rounded,
                  message:
                      'This playlist is empty. Use the ⋮ menu on any song to add it here.',
                )
              else
                TrackRows(
                  tracks: tracks,
                  playbackContext: playbackContext,
                  actionsFor: (index, _) => [
                    TrackAction(
                      icon: Icons.remove_circle_outline_rounded,
                      label: 'Remove from this playlist',
                      isDestructive: true,
                      onSelected: () =>
                          _remove(context, ref, loaded.items[index]),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EditPlaylistDialog extends StatefulWidget {
  const _EditPlaylistDialog({required this.playlist});

  final Playlist playlist;

  @override
  State<_EditPlaylistDialog> createState() => _EditPlaylistDialogState();
}

class _EditPlaylistDialogState extends State<_EditPlaylistDialog> {
  late final _title = TextEditingController(text: widget.playlist.title);
  late final _description = TextEditingController(
    text: widget.playlist.description ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Enter a playlist name');
      return;
    }
    Navigator.of(
      context,
    ).pop((title: title, description: _description.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: LinerColors.darkElevated,
      title: const Text(
        'Edit details',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            maxLength: PlaylistRules.titleMaxLength,
            style: const TextStyle(color: Colors.white),
            decoration: darkInputDecoration(
              hint: 'Playlist name',
              errorText: _error,
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _description,
            maxLength: PlaylistRules.descriptionMaxLength,
            maxLines: 2,
            style: const TextStyle(color: Colors.white),
            decoration: darkInputDecoration(hint: 'Description (optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: LinerColors.accentPrimary,
            foregroundColor: Colors.white,
          ),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
