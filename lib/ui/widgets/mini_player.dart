import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/player_provider.dart';
import '../screens/player/fullscreen_player.dart';
import 'cover_image.dart';
import 'like_button.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(
      playerStateProvider.select(
        (s) => (
          track: s.currentTrack,
          isPlaying: s.isPlaying,
          isBuffering: s.isBuffering,
          hasError: s.hasError,
        ),
      ),
    );
    final track = view.track;
    if (track == null) return const SizedBox.shrink();

    final notifier = ref.read(playerStateProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(fullscreenPlayerRoute()),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: LinerColors.darkElevated.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: LinerColors.darkBorderSecondary.withValues(alpha: 0.8),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CoverImage(
                          url: track.coverUrl,
                          fallbackUrl: track.coverFallbackUrl,
                          width: 44,
                          height: 44,
                          backgroundColor: LinerColors.darkPanel,
                          iconColor: Colors.white54,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                                color: LinerColors.darkTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              view.hasError
                                  ? 'Playback unavailable'
                                  : track.artistName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: view.hasError
                                    ? Colors.redAccent
                                    : LinerColors.darkTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      LikeButton(
                        track: track,
                        inactiveColor: LinerColors.darkTextSecondary,
                      ),
                      IconButton(
                        splashRadius: 22,
                        icon: view.isBuffering
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                view.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                        onPressed: notifier.togglePlayPause,
                      ),
                      IconButton(
                        splashRadius: 20,
                        icon: const Icon(
                          Icons.skip_next_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: notifier.next,
                      ),
                    ],
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _Progress(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Progress extends ConsumerWidget {
  const _Progress();

  @override
  Widget build(BuildContext context, WidgetRef ref) => LinearProgressIndicator(
    value: ref.watch(playerStateProvider.select((s) => s.progress)),
    backgroundColor: Colors.white.withValues(alpha: 0.08),
    color: LinerColors.accentPrimary,
    minHeight: 2.2,
  );
}
