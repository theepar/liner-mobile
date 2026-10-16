import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/player_state.dart';
import '../../../providers/music_provider.dart';
import '../../../providers/player_provider.dart';
import '../../widgets/song_tile.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  final List<Map<String, dynamic>> _categories = const [
    {'title': 'Pop', 'color': Color(0xFFE11D48)},
    {'title': 'Hip-Hop', 'color': Color(0xFFD97706)},
    {'title': 'Electronic', 'color': Color(0xFF0284C7)},
    {'title': 'Synthwave', 'color': Color(0xFF7C3AED)},
    {'title': 'Indie & Alt', 'color': Color(0xFF059669)},
    {'title': 'Lo-Fi Beats', 'color': Color(0xFF4F46E5)},
    {'title': 'Rock', 'color': Color(0xFFDC2626)},
    {'title': 'Chill & Focus', 'color': Color(0xFF0D9488)},
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final searchNotifier = ref.read(searchProvider.notifier);
    final playerState = ref.watch(playerStateProvider);
    final playerNotifier = ref.read(playerStateProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Header Title
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text(
                'Search',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 28,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            // Search Input Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                decoration: BoxDecoration(
                  color: LinerColors.darkElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: LinerColors.darkBorderSecondary, width: 1),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Songs, artists, or playlists...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.white60, size: 22),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              searchNotifier.clear();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onChanged: (val) {
                    searchNotifier.search(val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Content: Categories or Search Results
            Expanded(
              child: searchState.isLoading
                  ? const Center(child: CircularProgressIndicator(color: LinerColors.accentPrimary))
                  : searchState.query.isEmpty
                      ? _buildCategoriesGrid(searchNotifier)
                      : _buildSearchResults(searchState, playerState, playerNotifier),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesGrid(SearchNotifier notifier) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        const Text(
          'Browse Categories',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.8,
          ),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final cat = _categories[index];
            final color = cat['color'] as Color;
            return GestureDetector(
              onTap: () {
                _searchCtrl.text = cat['title'] as String;
                notifier.search(cat['title'] as String);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.85), color.withValues(alpha: 0.4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Text(
                  cat['title'] as String,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSearchResults(
    SearchState searchState,
    PlayerStateData playerState,
    PlayerNotifier playerNotifier,
  ) {
    if (searchState.tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 50, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              'No results found for "${searchState.query}"',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
      itemCount: searchState.tracks.length,
      itemBuilder: (context, index) {
        final track = searchState.tracks[index];
        final isPlaying = playerState.currentTrack?.id == track.id;

        return SongTile(
          track: track,
          isPlaying: isPlaying,
          isLiked: playerState.likedTrackIds.contains(track.id),
          onTap: () {
            playerNotifier.playTrack(track, searchState.tracks, index);
          },
          onLikeToggle: () {
            playerNotifier.toggleLike(track.id);
          },
        );
      },
    );
  }
}
