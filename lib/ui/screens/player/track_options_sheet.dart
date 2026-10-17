import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/track.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/library_provider.dart';
import '../../../providers/player_provider.dart';
import '../../navigation/navigation_helpers.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/track_action.dart';
import 'add_to_playlist_sheet.dart';

Future<void> showTrackOptionsSheet(
  BuildContext context,
  Track track, {
  List<TrackAction> extraActions = const [],
  VoidCallback? beforeNavigate,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: LinerColors.darkElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _TrackOptionsSheet(
      track: track,
      origin: context,
      extraActions: extraActions,
      beforeNavigate: beforeNavigate,
    ),
  );
}

class _TrackOptionsSheet extends ConsumerWidget {
  const _TrackOptionsSheet({
    required this.track,
    required this.origin,
    required this.extraActions,
    this.beforeNavigate,
  });

  final Track track;

  final BuildContext origin;
  final List<TrackAction> extraActions;
  final VoidCallback? beforeNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLiked = ref.watch(
      likedTrackIdsProvider.select((ids) => ids.contains(track.id)),
    );
    final player = ref.read(playerStateProvider.notifier);
    final navigator = Navigator.of(origin);
    final messenger = ScaffoldMessenger.of(origin);

    void say(String message) => messenger.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );

    Widget option({
      required IconData icon,
      required String label,
      required FutureOr<void> Function() onSelected,
      bool isDestructive = false,
    }) {
      final color = isDestructive ? Colors.redAccent : Colors.white;
      return ListTile(
        leading: Icon(icon, color: color, size: 22),
        title: Text(label, style: TextStyle(color: color)),
        onTap: () {
          Navigator.of(context).pop();
          unawaited(Future<void>.sync(onSelected));
        },
      );
    }

    final artistId = track.artistId;
    final albumId = track.albumId;

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CoverImage(
                  url: track.coverUrl,
                  fallbackUrl: track.coverFallbackUrl,
                  width: 48,
                  height: 48,
                ),
              ),
              title: Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                track.artistName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54),
              ),
            ),
            const Divider(height: 1, color: LinerColors.darkBorderSecondary),
            option(
              icon: Icons.play_arrow_rounded,
              label: 'Play now',
              onSelected: () => player.playTrack(track),
            ),
            option(
              icon: Icons.radio_rounded,
              label: 'Start radio',
              onSelected: () => player.startRadio(track),
            ),
            option(
              icon: Icons.queue_play_next_rounded,
              label: 'Play next',
              onSelected: () {
                player.addToQueue(track, next: true);
                say('Playing next');
              },
            ),
            option(
              icon: Icons.playlist_play_rounded,
              label: 'Add to queue',
              onSelected: () {
                player.addToQueue(track);
                say('Added to queue');
              },
            ),
            option(
              icon: isLiked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label: isLiked ? 'Remove from liked songs' : 'Add to liked songs',
              onSelected: () async {
                if (origin.mounted) await toggleLike(origin, ref, track);
              },
            ),
            option(
              icon: Icons.playlist_add_rounded,
              label: 'Add to playlist',
              onSelected: () async {
                if (origin.mounted) {
                  await showAddToPlaylistSheet(origin, track);
                }
              },
            ),
            if (artistId != null && artistId.isNotEmpty)
              option(
                icon: Icons.person_rounded,
                label: 'Go to artist',
                onSelected: () {
                  beforeNavigate?.call();
                  unawaited(openArtist(navigator, artistId));
                },
              ),
            if (albumId != null && albumId.isNotEmpty)
              option(
                icon: Icons.album_rounded,
                label: 'Go to album',
                onSelected: () {
                  beforeNavigate?.call();
                  unawaited(openAlbum(navigator, albumId));
                },
              ),
            option(
              icon: Icons.link_rounded,
              label: 'Copy link',
              onSelected: () async {
                await Clipboard.setData(ClipboardData(text: track.shareUrl));
                say('Link copied');
              },
            ),
            for (final action in extraActions)
              option(
                icon: action.icon,
                label: action.label,
                isDestructive: action.isDestructive,
                onSelected: action.onSelected,
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
