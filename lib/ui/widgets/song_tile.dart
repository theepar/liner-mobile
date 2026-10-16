import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/models/track.dart';
import '../../core/theme/app_theme.dart';

class SongTile extends StatelessWidget {
  final Track track;
  final int? rank;
  final bool isPlaying;
  final bool isLiked;
  final VoidCallback onTap;
  final VoidCallback? onLikeToggle;
  final VoidCallback? onMoreOptions;

  const SongTile({
    super.key,
    required this.track,
    this.rank,
    this.isPlaying = false,
    this.isLiked = false,
    required this.onTap,
    this.onLikeToggle,
    this.onMoreOptions,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
        child: Row(
          children: [
            if (rank != null) ...[
              SizedBox(
                width: 26,
                child: Text(
                  rank.toString(),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isPlaying ? LinerColors.accentPrimary : LinerColors.darkTextTertiary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: track.coverUrl,
                width: 46,
                height: 46,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 46,
                  height: 46,
                  color: LinerColors.darkElevated,
                ),
                errorWidget: (context, url, error) => Container(
                  width: 46,
                  height: 46,
                  color: LinerColors.darkElevated,
                  child: const Icon(Icons.music_note, size: 20, color: LinerColors.darkTextTertiary),
                ),
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
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isPlaying ? LinerColors.accentPrimary : LinerColors.darkTextPrimary,
                          ),
                        ),
                      ),
                      if (track.explicit) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: LinerColors.darkTextTertiary.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            'E',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
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
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                      color: LinerColors.darkTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (onLikeToggle != null)
              IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isLiked ? LinerColors.accentPrimary : LinerColors.darkTextTertiary,
                  size: 20,
                ),
                splashRadius: 20,
                onPressed: onLikeToggle,
              ),
            if (onMoreOptions != null)
              IconButton(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: LinerColors.darkTextTertiary,
                  size: 20,
                ),
                splashRadius: 20,
                onPressed: onMoreOptions,
              ),
          ],
        ),
      ),
    );
  }
}
