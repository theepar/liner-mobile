import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/player_state.dart';
import '../../../providers/player_provider.dart';
import '../../widgets/dynamic_mesh_background.dart';
import 'lyrics_view.dart';

class FullscreenPlayer extends ConsumerWidget {
  const FullscreenPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final notifier = ref.read(playerStateProvider.notifier);
    final track = playerState.currentTrack;

    if (track == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text('No track playing', style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    final isPlaying = playerState.isPlaying;
    final isLyricsOpen = playerState.isLyricsOpen;

    return Scaffold(
      backgroundColor: Colors.black,
      body: DynamicMeshBackground(
        isPlaying: isPlaying,
        child: SafeArea(
          child: Column(
            children: [
              // ── Top Bar ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 32),
                      splashRadius: 24,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Column(
                      children: [
                        Text(
                          'NOW PLAYING',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                            letterSpacing: 1.5,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          track.albumName ?? 'Liner',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 26),
                      splashRadius: 24,
                      onPressed: () => _showTrackOptions(context, track),
                    ),
                  ],
                ),
              ),

              // ── Middle Area (Album Cover or Lyrics) ───────────────
              Expanded(
                child: isLyricsOpen
                    ? const LyricsView()
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 1.0,
                            child: Hero(
                              tag: 'cover_${track.id}',
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      blurRadius: 30,
                                      offset: const Offset(0, 14),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: CachedNetworkImage(
                                    imageUrl: track.coverUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: LinerColors.darkElevated,
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      color: LinerColors.darkElevated,
                                      child: const Icon(Icons.music_note, color: Colors.white30, size: 60),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),

              // ── Track Title & Artist & Like Button ────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                              fontSize: 22,
                              color: Colors.white,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            track.artistName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w400,
                              fontSize: 15,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        playerState.isCurrentLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: playerState.isCurrentLiked ? LinerColors.accentPrimary : Colors.white60,
                        size: 26,
                      ),
                      splashRadius: 24,
                      onPressed: () => notifier.toggleLike(track.id),
                    ),
                  ],
                ),
              ),

              // ── Timeline Slider ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3.5,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
                        thumbColor: Colors.white,
                        overlayColor: Colors.white.withValues(alpha: 0.1),
                      ),
                      child: Slider(
                        value: playerState.progress,
                        onChanged: (val) {
                          final targetMs = (val * playerState.duration.inMilliseconds).round();
                          notifier.seek(Duration(milliseconds: targetMs));
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(playerState.position),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                          Text(
                            _formatDuration(playerState.duration),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Primary Playback Controls ─────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Shuffle
                    IconButton(
                      icon: Icon(
                        Icons.shuffle_rounded,
                        color: playerState.isShuffle ? LinerColors.accentPrimary : Colors.white54,
                        size: 24,
                      ),
                      splashRadius: 22,
                      onPressed: () => notifier.toggleShuffle(),
                    ),
                    // Previous
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 36),
                      splashRadius: 26,
                      onPressed: () => notifier.previous(),
                    ),
                    // Play / Pause (Liner Primary Red button)
                    GestureDetector(
                      onTap: () => notifier.togglePlayPause(),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: LinerColors.accentPrimary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: LinerColors.accentPrimary.withValues(alpha: 0.4),
                              blurRadius: 18,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: playerState.isBuffering
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Icon(
                                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 38,
                                ),
                        ),
                      ),
                    ),
                    // Next
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 36),
                      splashRadius: 26,
                      onPressed: () => notifier.next(),
                    ),
                    // Repeat
                    IconButton(
                      icon: Icon(
                        playerState.repeatMode == LinerRepeatMode.one
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                        color: playerState.repeatMode != LinerRepeatMode.off
                            ? LinerColors.accentPrimary
                            : Colors.white54,
                        size: 24,
                      ),
                      splashRadius: 22,
                      onPressed: () => notifier.cycleRepeatMode(),
                    ),
                  ],
                ),
              ),

              // ── Bottom Utility Row (Lyrics, Speed/Pitch, Queue) ───
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Lyrics toggle button
                    IconButton(
                      icon: Icon(
                        Icons.mic_rounded,
                        color: isLyricsOpen ? LinerColors.accentPrimary : Colors.white60,
                        size: 24,
                      ),
                      splashRadius: 22,
                      onPressed: () => notifier.toggleLyrics(),
                    ),
                    // Speed / Pitch adjustment button (tempo & pitch shift)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: Text(
                        '${playerState.playbackSpeed.toStringAsFixed(1)}x',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () => _showSpeedPitchDialog(context, ref, playerState),
                    ),
                    // Queue list button
                    IconButton(
                      icon: const Icon(Icons.queue_music_rounded, color: Colors.white60, size: 24),
                      splashRadius: 22,
                      onPressed: () => _showQueueModal(context, playerState, notifier),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _showSpeedPitchDialog(BuildContext context, WidgetRef ref, PlayerStateData state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: LinerColors.darkElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Speed & Pitch Controls',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Playback Speed', style: TextStyle(color: Colors.white70)),
                      Text('${state.playbackSpeed.toStringAsFixed(2)}x', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: state.playbackSpeed,
                    min: 0.5,
                    max: 2.0,
                    divisions: 15,
                    activeColor: LinerColors.accentPrimary,
                    onChanged: (val) {
                      setSheetState(() {});
                      ref.read(playerStateProvider.notifier).setSpeed(val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Pitch Key Shift', style: TextStyle(color: Colors.white70)),
                      Text('${state.pitch.toStringAsFixed(2)}x', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: state.pitch,
                    min: 0.5,
                    max: 1.5,
                    divisions: 10,
                    activeColor: LinerColors.accentPrimary,
                    onChanged: (val) {
                      setSheetState(() {});
                      ref.read(playerStateProvider.notifier).setPitch(val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      child: const Text('Reset to Normal (1.0x)', style: TextStyle(color: LinerColors.accentSecondary)),
                      onPressed: () {
                        ref.read(playerStateProvider.notifier).setSpeed(1.0);
                        ref.read(playerStateProvider.notifier).setPitch(1.0);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showQueueModal(BuildContext context, PlayerStateData state, PlayerNotifier notifier) {
    showModalBottomSheet(
      context: context,
      backgroundColor: LinerColors.darkElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Playing Queue (${state.queue.length})',
                  style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 18, color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: state.queue.length,
                  itemBuilder: (context, index) {
                    final t = state.queue[index];
                    final isCurrent = index == state.currentIndex;
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedNetworkImage(
                          imageUrl: t.coverUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCurrent ? LinerColors.accentPrimary : Colors.white,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        t.artistName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      trailing: isCurrent ? const Icon(Icons.volume_up_rounded, color: LinerColors.accentPrimary) : null,
                      onTap: () {
                        notifier.playTrack(t, state.queue, index);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTrackOptions(BuildContext context, dynamic track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: LinerColors.darkElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded, color: Colors.white),
                title: const Text('Add to Playlist', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.of(context).pop(),
              ),
              ListTile(
                leading: const Icon(Icons.person_rounded, color: Colors.white),
                title: Text('View Artist (${track.artistName})', style: const TextStyle(color: Colors.white)),
                onTap: () => Navigator.of(context).pop(),
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded, color: Colors.white),
                title: const Text('Share Song', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
    );
  }
}
