import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/track.dart';
import '../../../providers/music_provider.dart';
import '../../../providers/player_provider.dart';
import '../../widgets/song_tile.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  int _selectedTabIndex = 0;
  final List<String> _tabs = ['All', 'Liked Songs', 'Playlists', 'Artists'];

  final List<Playlist> _customPlaylists = [
    const Playlist(
      id: 'p_1',
      name: 'Midnight Coding',
      description: 'Atmospheric electronic & lo-fi',
      coverUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&auto=format&fit=crop&q=80',
      trackCount: 18,
    ),
    const Playlist(
      id: 'p_2',
      name: 'Gym Workout Synth',
      description: 'High tempo retrowave & synthwave',
      coverUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=600&auto=format&fit=crop&q=80',
      trackCount: 24,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerStateProvider);
    final playerNotifier = ref.read(playerStateProvider.notifier);
    final popularTracksAsync = ref.watch(popularTracksProvider);
    final popularArtists = ref.watch(popularArtistsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: "Your Library" + Add Playlist button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Your Library',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                    onPressed: () => _showCreatePlaylistDialog(context),
                  ),
                ],
              ),
            ),

            // Filter Tabs
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _tabs.length,
                itemBuilder: (context, index) {
                  final isSelected = index == _selectedTabIndex;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(_tabs[index]),
                      labelStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? Colors.white : Colors.white70,
                      ),
                      backgroundColor: LinerColors.darkElevated,
                      selectedColor: LinerColors.accentPrimary,
                      showCheckmark: false,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? Colors.transparent : LinerColors.darkBorderSecondary,
                        ),
                      ),
                      onSelected: (_) {
                        setState(() => _selectedTabIndex = index);
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Tab Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  // Liked Songs Hero Card (Show in 'All' or 'Liked Songs')
                  if (_selectedTabIndex == 0 || _selectedTabIndex == 1) ...[
                    GestureDetector(
                      onTap: () {
                        popularTracksAsync.whenData((tracks) {
                          if (tracks.isNotEmpty) {
                            playerNotifier.playTrack(tracks.first, tracks, 0);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF831843), Color(0xFF1E1B4B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF831843).withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.favorite_rounded, color: LinerColors.accentPrimary, size: 30),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Liked Songs',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${playerState.likedTrackIds.length} liked tracks',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: LinerColors.accentPrimary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Playlists Section (Show in 'All' or 'Playlists')
                  if (_selectedTabIndex == 0 || _selectedTabIndex == 2) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Text(
                        'Playlists',
                        style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 17, color: Colors.white),
                      ),
                    ),
                    ..._customPlaylists.map((pl) => ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: pl.coverUrl,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            ),
                          ),
                          title: Text(
                            pl.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 14),
                          ),
                          subtitle: Text(
                            'Playlist • ${pl.trackCount} tracks',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                          onTap: () {},
                        )),
                    const SizedBox(height: 16),
                  ],

                  // Artists Section (Show in 'All' or 'Artists')
                  if (_selectedTabIndex == 0 || _selectedTabIndex == 3) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Text(
                        'Followed Artists',
                        style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 17, color: Colors.white),
                      ),
                    ),
                    ...popularArtists.map<Widget>((Artist artist) => ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: CachedNetworkImage(
                              imageUrl: artist.avatarUrl,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            ),
                          ),
                          title: Text(
                            artist.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 14),
                          ),
                          subtitle: Text(
                            artist.listenersFormatted,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                          onTap: () {},
                        )),
                  ],

                  // Liked Songs Detailed List in 'Liked Songs' Tab
                  if (_selectedTabIndex == 1) ...[
                    popularTracksAsync.when(
                      data: (List<Track> tracks) => Column(
                        children: tracks.map<Widget>((Track track) {
                          return SongTile(
                            track: track,
                            isPlaying: playerState.currentTrack?.id == track.id,
                            isLiked: true,
                            onTap: () => playerNotifier.playTrack(track, tracks),
                            onLikeToggle: () => playerNotifier.toggleLike(track.id),
                          );
                        }).toList(),
                      ),
                      loading: () => const Center(child: CircularProgressIndicator(color: LinerColors.accentPrimary)),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LinerColors.darkElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New Playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: titleCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'My Playlist #1',
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: LinerColors.accentPrimary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create'),
            onPressed: () {
              if (titleCtrl.text.isNotEmpty) {
                setState(() {
                  _customPlaylists.add(Playlist(
                    id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                    name: titleCtrl.text,
                    coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&auto=format&fit=crop&q=80',
                    trackCount: 0,
                  ));
                });
              }
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
