import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/playback_event.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/music_provider.dart';
import '../../../providers/player_provider.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/liner_logo.dart';
import '../../widgets/song_card.dart';
import '../../widgets/song_tile.dart';
import '../../widgets/status_views.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 240,
            child: _TimeOfDayGlow(),
          ),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: _Header()),
                const SliverToBoxAdapter(child: _RecentlyPlayedSection()),
                const SliverToBoxAdapter(child: _DailyMixesSection()),
                const SliverToBoxAdapter(
                  child: _SectionTitle(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: LinerColors.accentPrimary,
                    title: 'Trending Now',
                    top: 24,
                  ),
                ),
                const _TrendingList(),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeOfDayGlow extends StatelessWidget {
  const _TimeOfDayGlow();

  static const _morning = [Color(0x33F59E0B), Color(0x1AF97316)];
  static const _afternoon = [Color(0x33FBBF24), Color(0x1A0EA5E9)];
  static const _evening = [Color(0x33F43F5E), Color(0x1AA855F7)];
  static const _night = [Color(0x3D4F46E5), Color(0x267C3AED)];

  List<Color> _colorsFor(int hour) {
    if (hour >= 5 && hour < 12) return _morning;
    if (hour >= 12 && hour < 17) return _afternoon;
    if (hour >= 17 && hour < 22) return _evening;
    return _night;
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [..._colorsFor(DateTime.now().hour), Colors.transparent],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          LinerLogoTile(size: 34),
          SizedBox(width: 10),
          Text(
            'LINER',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              letterSpacing: 1.2,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.top = 16,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, top, 20, 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentlyPlayedSection extends ConsumerWidget {
  const _RecentlyPlayedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(recentlyPlayedProvider)
        .when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => ErrorRetry(
            message: "Couldn't load your recently played tracks.",
            onRetry: () => ref.invalidate(recentlyPlayedProvider),
          ),
          data: (tracks) {
            if (tracks.isEmpty) return const SizedBox.shrink();
            final player = ref.read(playerStateProvider.notifier);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle(
                  icon: Icons.history_rounded,
                  iconColor: LinerColors.accentPrimary,
                  title: 'Jump Back In',
                ),
                SizedBox(
                  height: 195,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: tracks.length,
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      return SongCard(
                        title: track.title,
                        subtitle: track.artistName,
                        imageUrl: track.coverUrl,
                        fallbackImageUrl: track.coverFallbackUrl,
                        onTap: () => playTapped(
                          context,
                          ref,
                          track,
                          queue: tracks,
                          index: index,
                          playbackContext: PlaybackContext.library,
                        ),
                        onPlay: () => player.playTrack(
                          track,
                          tracks,
                          index,
                          PlaybackContext.library,
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
  }
}

class _DailyMixesSection extends ConsumerWidget {
  const _DailyMixesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(dailyMixesProvider)
        .when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => ErrorRetry(
            message: "Couldn't load your daily mixes.",
            onRetry: () => ref.invalidate(dailyMixesProvider),
          ),
          data: (mixes) {
            if (mixes.isEmpty) return const SizedBox.shrink();
            final player = ref.read(playerStateProvider.notifier);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: Colors.amber,
                  title: 'Made For You',
                  top: 24,
                ),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: mixes.length,
                    itemBuilder: (context, index) {
                      final mix = mixes[index];
                      return SongCard(
                        title: mix.title,
                        subtitle:
                            mix.description ??
                            '${mix.trackCount ?? mix.tracks.length} tracks',
                        imageUrl: mix.coverUrl,
                        onTap: () => player.playAll(
                          mix.tracks,
                          context: PlaybackContext.playlist(mix.id),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
  }
}

class _TrendingList extends ConsumerWidget {
  const _TrendingList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(popularTracksProvider)
        .when(
          loading: () =>
              const SliverToBoxAdapter(child: LoadingView(height: 160)),
          error: (_, _) => SliverToBoxAdapter(
            child: ErrorRetry(
              message: "Couldn't load trending tracks.",
              onRetry: () => ref.invalidate(popularTracksProvider),
            ),
          ),
          data: (tracks) {
            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverList.builder(
                itemCount: tracks.length,
                itemBuilder: (context, index) => SongTile(
                  track: tracks[index],
                  rank: index + 1,
                  onTap: () => playTapped(
                    context,
                    ref,
                    tracks[index],
                    queue: tracks,
                    index: index,
                    playbackContext: PlaybackContext.explore,
                  ),
                ),
              ),
            );
          },
        );
  }
}
