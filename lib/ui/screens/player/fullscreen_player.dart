import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/player_state.dart';
import '../../../core/models/track.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/dynamic_mesh_background.dart';
import '../../widgets/like_button.dart';
import 'add_to_playlist_sheet.dart';
import 'lyrics_view.dart';
import 'queue_sheet.dart';
import 'speed_pitch_sheet.dart';
import 'track_options_sheet.dart';

PageRouteBuilder<void> fullscreenPlayerRoute() => PageRouteBuilder<void>(
  pageBuilder: (_, _, _) => const FullscreenPlayer(),
  transitionsBuilder: (_, animation, _, child) => SlideTransition(
    position: animation.drive(
      Tween(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
    ),
    child: child,
  ),
);

class FullscreenPlayer extends ConsumerWidget {
  const FullscreenPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(
      playerStateProvider.select(
        (s) => (
          track: s.currentTrack,
          isPlaying: s.isPlaying,
          isBuffering: s.isBuffering,
          hasError: s.hasError,
          isLyricsOpen: s.isLyricsOpen,
          isShuffle: s.isShuffle,
          repeatMode: s.repeatMode,
          speed: s.playbackSpeed,
        ),
      ),
    );
    final animateBackground = ref.watch(
      settingsProvider.select((s) => s.animatedBackground),
    );
    final notifier = ref.read(playerStateProvider.notifier);
    final track = view.track;

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
          child: Text(
            'No track playing',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: DynamicMeshBackground(
        isPlaying: view.isPlaying && animateBackground,
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(track: track),
              Expanded(
                child: view.isLyricsOpen
                    ? const LyricsView()
                    : _Artwork(track: track),
              ),
              _TrackInfo(track: track, hasError: view.hasError),
              const _SeekBar(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      tooltip: 'Shuffle',
                      splashRadius: 22,
                      icon: Icon(
                        Icons.shuffle_rounded,
                        color: view.isShuffle
                            ? LinerColors.accentPrimary
                            : Colors.white54,
                        size: 24,
                      ),
                      onPressed: notifier.toggleShuffle,
                    ),
                    IconButton(
                      tooltip: 'Previous',
                      splashRadius: 26,
                      icon: const Icon(
                        Icons.skip_previous_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                      onPressed: notifier.previous,
                    ),
                    _PlayPauseButton(
                      isPlaying: view.isPlaying,
                      isBuffering: view.isBuffering,
                      onPressed: notifier.togglePlayPause,
                    ),
                    IconButton(
                      tooltip: 'Next',
                      splashRadius: 26,
                      icon: const Icon(
                        Icons.skip_next_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                      onPressed: notifier.next,
                    ),
                    IconButton(
                      tooltip: 'Repeat',
                      splashRadius: 22,
                      icon: Icon(
                        view.repeatMode == LinerRepeatMode.one
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                        color: view.repeatMode == LinerRepeatMode.off
                            ? Colors.white54
                            : LinerColors.accentPrimary,
                        size: 24,
                      ),
                      onPressed: notifier.cycleRepeatMode,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      tooltip: 'Lyrics',
                      splashRadius: 22,
                      icon: Icon(
                        Icons.mic_rounded,
                        color: view.isLyricsOpen
                            ? LinerColors.accentPrimary
                            : Colors.white60,
                        size: 24,
                      ),
                      onPressed: notifier.toggleLyrics,
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: Text(
                        '${view.speed.toStringAsFixed(1)}x',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () => showSpeedPitchSheet(context),
                    ),
                    IconButton(
                      tooltip: 'Queue',
                      splashRadius: 22,
                      icon: const Icon(
                        Icons.queue_music_rounded,
                        color: Colors.white60,
                        size: 24,
                      ),
                      onPressed: () => showQueueSheet(context),
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
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'Close',
            splashRadius: 24,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 32,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'NOW PLAYING',
                  style: TextStyle(
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
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'More',
            splashRadius: 24,
            icon: const Icon(
              Icons.more_horiz_rounded,
              color: Colors.white,
              size: 26,
            ),
            onPressed: () => showTrackOptionsSheet(
              context,
              track,
              beforeNavigate: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
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
              child: CoverImage(
                url: track.coverUrl,
                fallbackUrl: track.coverFallbackUrl,
                iconSize: 60,
                iconColor: Colors.white30,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackInfo extends StatelessWidget {
  const _TrackInfo({required this.track, required this.hasError});

  final Track track;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    letterSpacing: -0.4,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasError
                      ? 'Playback unavailable. Tap play to retry.'
                      : track.artistName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    color: hasError
                        ? Colors.redAccent
                        : Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Add to playlist',
            splashRadius: 24,
            icon: const Icon(
              Icons.playlist_add_rounded,
              color: Colors.white60,
              size: 26,
            ),
            onPressed: () => showAddToPlaylistSheet(context, track),
          ),
          LikeButton(track: track, size: 26, inactiveColor: Colors.white60),
        ],
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.isPlaying,
    required this.isBuffering,
    required this.onPressed,
  });

  final bool isPlaying;
  final bool isBuffering;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
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
          child: isBuffering
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 38,
                ),
        ),
      ),
    );
  }
}

/// Seeks only on drag release to avoid flooding the audio engine.
class _SeekBar extends ConsumerStatefulWidget {
  const _SeekBar();

  @override
  ConsumerState<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends ConsumerState<_SeekBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final timing = ref.watch(
      playerStateProvider.select(
        (s) =>
            (position: s.position, duration: s.duration, progress: s.progress),
      ),
    );
    final value = _dragValue ?? timing.progress;
    final shownPosition = _dragValue == null
        ? timing.position
        : Duration(
            milliseconds: (_dragValue! * timing.duration.inMilliseconds)
                .round(),
          );
    final labelStyle = TextStyle(
      fontSize: 12,
      color: Colors.white.withValues(alpha: 0.55),
    );

    return Padding(
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
              value: value,
              onChanged: (next) => setState(() => _dragValue = next),
              onChangeEnd: (next) {
                final target = Duration(
                  milliseconds: (next * timing.duration.inMilliseconds).round(),
                );
                setState(() => _dragValue = null);
                ref.read(playerStateProvider.notifier).seek(target);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(formatDuration(shownPosition), style: labelStyle),
                Text(formatDuration(timing.duration), style: labelStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
