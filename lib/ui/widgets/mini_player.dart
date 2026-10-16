import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/player_provider.dart';
import '../screens/player/fullscreen_player.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final track = playerState.currentTrack;

    if (track == null) {
      return const SizedBox.shrink();
    }

    final isPlaying = playerState.isPlaying;
    final progress = playerState.progress;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (context, anim, secondaryAnim) => const FullscreenPlayer(),
              transitionsBuilder: (context, anim, secondaryAnim, child) {
                const begin = Offset(0.0, 1.0);
                const end = Offset.zero;
                const curve = Curves.easeOutCubic;
                final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                return SlideTransition(position: anim.drive(tween), child: child);
              },
            ),
          );
        },
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: LinerColors.darkElevated.withOpacity(0.95),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: LinerColors.darkBorderSecondary.withOpacity(0.8), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                // Main content row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      // Album Cover Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: track.coverUrl,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 44,
                            height: 44,
                            color: LinerColors.darkPanel,
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 44,
                            height: 44,
                            color: LinerColors.darkPanel,
                            child: const Icon(Icons.music_note, color: Colors.white54, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Title & Artist
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
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                                color: LinerColors.darkTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              track.artistName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w400,
                                fontSize: 11.5,
                                color: LinerColors.darkTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Like button
                      IconButton(
                        icon: Icon(
                          playerState.isCurrentLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: playerState.isCurrentLiked
                              ? LinerColors.accentPrimary
                              : LinerColors.darkTextSecondary,
                          size: 20,
                        ),
                        splashRadius: 20,
                        onPressed: () {
                          ref.read(playerStateProvider.notifier).toggleLike(track.id);
                        },
                      ),
                      // Play / Pause button
                      IconButton(
                        icon: playerState.isBuffering
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Icon(
                                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                        splashRadius: 22,
                        onPressed: () {
                          ref.read(playerStateProvider.notifier).togglePlayPause();
                        },
                      ),
                      // Next track button
                      IconButton(
                        icon: const Icon(
                          Icons.skip_next_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        splashRadius: 20,
                        onPressed: () {
                          ref.read(playerStateProvider.notifier).next();
                        },
                      ),
                    ],
                  ),
                ),
                // Bottom thin linear progress indicator
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: const AlwaysStoppedAnimation<Color>(LinerColors.accentPrimary),
                    minHeight: 2.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
