import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/playback_event.dart';
import '../../core/models/track.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/player_provider.dart';
import '../utils/ui_helpers.dart';
import 'cover_image.dart';
import 'song_tile.dart';
import 'track_action.dart';

/// Cover, title and details at the top of an album, playlist or artist page.
class CollectionHeader extends StatelessWidget {
  const CollectionHeader({
    super.key,
    required this.title,
    this.coverUrl = '',
    this.coverFallbackUrl,
    this.subtitle,
    this.details,
    this.description,
    this.isCircular = false,
    this.placeholderIcon = Icons.music_note,
    this.titleBadge,
    this.actions = const [],
  });

  final String title;
  final String coverUrl;
  final String? coverFallbackUrl;
  final String? subtitle;
  final String? details;
  final String? description;
  final bool isCircular;
  final IconData placeholderIcon;
  final Widget? titleBadge;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    const size = 200.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isCircular ? size / 2 : 14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isCircular ? size / 2 : 14),
              child: CoverImage(
                url: coverUrl,
                fallbackUrl: coverFallbackUrl,
                width: size,
                height: size,
                iconSize: 56,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: Colors.white,
                  ),
                ),
              ),
              if (titleBadge case final badge?) ...[
                const SizedBox(width: 6),
                badge,
              ],
            ],
          ),
          if (subtitle case final subtitle?) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: LinerColors.darkTextSecondary,
              ),
            ),
          ],
          if (details case final details?) ...[
            const SizedBox(height: 2),
            Text(
              details,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
          if (description case final description?
              when description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              description,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Colors.white60,
              ),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}

/// Play and shuffle buttons for a list of tracks.
class PlayActions extends ConsumerWidget {
  const PlayActions({super.key, required this.tracks, this.playbackContext});

  final List<Track> tracks;
  final PlaybackContext? playbackContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.read(playerStateProvider.notifier);
    final enabled = tracks.isNotEmpty;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: LinerColors.accentPrimary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Play'),
          onPressed: enabled
              ? () => player.playAll(tracks, context: playbackContext)
              : null,
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: LinerColors.darkBorderSecondary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          icon: const Icon(Icons.shuffle_rounded, size: 18),
          label: const Text('Shuffle'),
          onPressed: enabled
              ? () => player.playAll(
                  ([...tracks]..shuffle(Random())),
                  context: playbackContext,
                )
              : null,
        ),
      ],
    );
  }
}

/// A column of [SongTile]s that plays the whole list from the tapped track.
class TrackRows extends ConsumerWidget {
  const TrackRows({
    super.key,
    required this.tracks,
    this.playbackContext,
    this.showRank = false,
    this.actionsFor,
  });

  final List<Track> tracks;
  final PlaybackContext? playbackContext;
  final bool showRank;

  /// Extra menu actions for the track at an index (for example removal).
  final List<TrackAction> Function(int index, Track track)? actionsFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        for (final (index, track) in tracks.indexed)
          SongTile(
            track: track,
            rank: showRank ? index + 1 : null,
            extraActions: actionsFor?.call(index, track) ?? const [],
            onTap: () => playTapped(
              context,
              ref,
              track,
              queue: tracks,
              index: index,
              playbackContext: playbackContext,
            ),
          ),
      ],
    );
  }
}
