import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/track.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/library_provider.dart';
import '../utils/ui_helpers.dart';

class LikeButton extends ConsumerWidget {
  const LikeButton({
    super.key,
    required this.track,
    this.size = 20,
    this.inactiveColor = LinerColors.darkTextTertiary,
  });

  final Track track;
  final double size;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLiked = ref.watch(
      likedTrackIdsProvider.select((ids) => ids.contains(track.id)),
    );
    return IconButton(
      tooltip: isLiked ? 'Remove from liked songs' : 'Add to liked songs',
      splashRadius: size + 2,
      icon: Icon(
        isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: isLiked ? LinerColors.accentPrimary : inactiveColor,
        size: size,
      ),
      onPressed: () => toggleLike(context, ref, track),
    );
  }
}
