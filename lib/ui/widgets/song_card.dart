import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'cover_image.dart';

class SongCard extends StatelessWidget {
  const SongCard({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.onTap,
    this.subtitle,
    this.fallbackImageUrl,
    this.onPlay,
    this.width = 140,
    this.height = 140,
    this.isCircular = false,
  });

  final String title;
  final String? subtitle;
  final String imageUrl;
  final String? fallbackImageUrl;
  final VoidCallback onTap;
  final VoidCallback? onPlay;
  final double width;
  final double height;
  final bool isCircular;

  @override
  Widget build(BuildContext context) {
    final textAlign = isCircular ? TextAlign.center : TextAlign.start;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: isCircular
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(
                    isCircular ? width / 2 : 12,
                  ),
                  child: CoverImage(
                    url: imageUrl,
                    fallbackUrl: fallbackImageUrl,
                    width: width,
                    height: height,
                    iconSize: 28,
                  ),
                ),
                if (onPlay != null && !isCircular)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: onPlay,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: LinerColors.accentPrimary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: textAlign,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: LinerColors.darkTextPrimary,
              ),
            ),
            if (subtitle case final subtitle?) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: textAlign,
                style: const TextStyle(
                  fontSize: 11,
                  color: LinerColors.darkTextSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
