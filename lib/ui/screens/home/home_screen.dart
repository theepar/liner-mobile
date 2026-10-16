import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/music_provider.dart';
import '../../../providers/player_provider.dart';
import '../../widgets/song_card.dart';
import '../../widgets/song_tile.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  LinearGradient _getTimeOfDayGlow() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x33F59E0B), Color(0x1AF97316), Colors.transparent],
      );
    } else if (hour >= 12 && hour < 17) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x33FBBF24), Color(0x1A0EA5E9), Colors.transparent],
      );
    } else if (hour >= 17 && hour < 22) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x33F43F5E), Color(0x1AA855F7), Colors.transparent],
      );
    }
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0x3D4F46E5), Color(0x267C3AED), Colors.transparent],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popularTracksAsync = ref.watch(popularTracksProvider);
    final dailyMixesAsync = ref.watch(dailyMixesProvider);
    final popularArtists = ref.watch(popularArtistsProvider);
    final playerState = ref.watch(playerStateProvider);
    final playerNotifier = ref.read(playerStateProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 240,
            child: Container(
              decoration: BoxDecoration(gradient: _getTimeOfDayGlow()),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: LinerColors.accentPrimary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Text(
                                  'L',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 20,
                                    color: Colors.white,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'LINER',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                                letterSpacing: 1.2,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.flash_on_rounded, color: Colors.amber, size: 22),
                              onPressed: () {},
                            ),
                            IconButton(
                              icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 22),
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: Row(
                          children: [
                            Icon(Icons.history_rounded, size: 20, color: LinerColors.accentPrimary),
                            SizedBox(width: 8),
                            Text(
                              'Jump Back In',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      popularTracksAsync.when(
                        data: (tracks) => SizedBox(
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
                                onTap: () => playerNotifier.playTrack(track, tracks, index),
                                onPlay: () => playerNotifier.playTrack(track, tracks, index),
                              );
                            },
                          ),
                        ),
                        loading: () => const SizedBox(
                          height: 180,
                          child: Center(child: CircularProgressIndicator(color: LinerColors.accentPrimary)),
                        ),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
                        child: Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded, size: 20, color: Colors.amber),
                            SizedBox(width: 8),
                            Text(
                              'Made For You',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      dailyMixesAsync.when(
                        data: (mixes) => SizedBox(
                          height: 200,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: mixes.length,
                            itemBuilder: (context, index) {
                              final mix = mixes[index];
                              return SongCard(
                                title: mix.name,
                                subtitle: mix.description ?? '${mix.trackCount} tracks',
                                imageUrl: mix.coverUrl,
                                onTap: () {},
                              );
                            },
                          ),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
                        child: Text(
                          'Popular Artists',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 160,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: popularArtists.length,
                          itemBuilder: (context, index) {
                            final artist = popularArtists[index];
                            return SongCard(
                              title: artist.name,
                              subtitle: artist.listenersFormatted,
                              imageUrl: artist.avatarUrl,
                              isCircular: true,
                              width: 110,
                              height: 110,
                              onTap: () {},
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.local_fire_department_rounded, size: 22, color: LinerColors.accentPrimary),
                            SizedBox(width: 8),
                            Text(
                              'Trending Now',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Top 20',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                popularTracksAsync.when(
                  data: (tracks) => SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final track = tracks[index];
                          final isCurrentPlaying = playerState.currentTrack?.id == track.id;
                          return SongTile(
                            track: track,
                            rank: index + 1,
                            isPlaying: isCurrentPlaying,
                            isLiked: playerState.likedTrackIds.contains(track.id),
                            onTap: () => playerNotifier.playTrack(track, tracks, index),
                            onLikeToggle: () => playerNotifier.toggleLike(track.id),
                          );
                        },
                        childCount: tracks.length,
                      ),
                    ),
                  ),
                  loading: () => const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator(color: LinerColors.accentPrimary)),
                    ),
                  ),
                  error: (e, _) => SliverToBoxAdapter(
                    child: Center(child: Text('Failed to load tracks: $e', style: const TextStyle(color: Colors.white54))),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
