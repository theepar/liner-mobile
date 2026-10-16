import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/track.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/player_provider.dart';
import 'cover_image.dart';
import 'like_button.dart';

class SongTile extends ConsumerWidget {
  const SongTile({
    super.key,
    required this.track,
    required this.onTap,
    this.rank,
  });

  final Track track;
  final int? rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(
      currentTrackIdProvider.select((id) => id == track.id),
    );
    final highlight = isPlaying
        ? LinerColors.accentPrimary
        : LinerColors.darkTextPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
        child: Row(
          children: [
            if (rank case final rank?) ...[
              SizedBox(
                width: 26,
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isPlaying
                        ? LinerColors.accentPrimary
                        : LinerColors.darkTextTertiary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CoverImage(
                url: track.coverUrl,
                fallbackUrl: track.coverFallbackUrl,
                width: 46,
                height: 46,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: highlight,
                          ),
                        ),
                      ),
                      if (track.explicit) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: LinerColors.darkTextTertiary.withValues(
                              alpha: 0.3,
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            'E',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    track.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: LinerColors.darkTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            LikeButton(track: track),
          ],
        ),
      ),
    );
  }
}
