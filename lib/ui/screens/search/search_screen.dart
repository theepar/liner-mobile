import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/playback_event.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/search_history_provider.dart';
import '../../../providers/search_provider.dart';
import '../../navigation/navigation_helpers.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/song_tile.dart';
import '../../widgets/status_views.dart';

enum _SearchFilter {
  all('All'),
  tracks('Songs'),
  artists('Artists'),
  albums('Albums'),
  playlists('Playlists');

  const _SearchFilter(this.label);

  final String label;
}

typedef _Category = ({String title, Color color});

const _categories = <_Category>[
  (title: 'Pop', color: Color(0xFFE11D48)),
  (title: 'Hip-Hop', color: Color(0xFFD97706)),
  (title: 'Electronic', color: Color(0xFF0284C7)),
  (title: 'Synthwave', color: Color(0xFF7C3AED)),
  (title: 'Indie & Alt', color: Color(0xFF059669)),
  (title: 'Lo-Fi Beats', color: Color(0xFF4F46E5)),
  (title: 'Rock', color: Color(0xFFDC2626)),
  (title: 'Chill & Focus', color: Color(0xFF0D9488)),
];

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  _SearchFilter _filter = _SearchFilter.all;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _runSearch(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    ref.read(searchProvider.notifier).search(query);
  }

  void _remember() =>
      ref.read(searchHistoryProvider.notifier).add(_controller.text);

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(searchProvider);
    final notifier = ref.read(searchProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text(
                'Search',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 28,
                  letterSpacing: -0.5,
                  color: Colors.white,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                decoration: BoxDecoration(
                  color: LinerColors.darkElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: LinerColors.darkBorderSecondary),
                ),
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Songs, artists, albums or playlists...',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Colors.white60,
                      size: 22,
                    ),
                    suffixIcon: search.query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white60,
                              size: 18,
                            ),
                            onPressed: () {
                              _controller.clear();
                              notifier.clear();
                            },
                          ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  onChanged: notifier.search,
                  onSubmitted: (_) => _remember(),
                ),
              ),
            ),
            if (search.query.isNotEmpty) ...[
              const SizedBox(height: 8),
              _FilterPills(
                selected: _filter,
                onSelected: (filter) => setState(() => _filter = filter),
              ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: search.query.isEmpty
                  ? _Browse(onSelected: _runSearch)
                  : search.isLoading
                  ? const LoadingView()
                  : search.hasError
                  ? ErrorRetry(
                      message: 'Search failed.',
                      onRetry: () => notifier.search(search.query),
                    )
                  : _Results(
                      search: search,
                      filter: _filter,
                      onOpened: _remember,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPills extends StatelessWidget {
  const _FilterPills({required this.selected, required this.onSelected});

  final _SearchFilter selected;
  final ValueChanged<_SearchFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _SearchFilter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _SearchFilter.values[index];
          final isSelected = filter == selected;
          return GestureDetector(
            onTap: () => onSelected(filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : LinerColors.darkElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? Colors.white
                      : LinerColors.darkBorderSecondary,
                ),
              ),
              child: Text(
                filter.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.black : Colors.white70,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Shown while the query is empty: recent searches and quick topics.
class _Browse extends ConsumerWidget {
  const _Browse({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(searchHistoryProvider);
    final historyNotifier = ref.read(searchHistoryProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        if (history.isNotEmpty) ...[
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent searches',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: Colors.white,
                  ),
                ),
              ),
              TextButton(
                onPressed: historyNotifier.clear,
                child: const Text(
                  'Clear',
                  style: TextStyle(color: LinerColors.accentSecondary),
                ),
              ),
            ],
          ),
          for (final query in history.take(8))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history_rounded, color: Colors.white54),
              title: Text(
                query,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white),
              ),
              trailing: IconButton(
                tooltip: 'Remove',
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white38,
                  size: 18,
                ),
                onPressed: () => historyNotifier.remove(query),
              ),
              onTap: () => onSelected(query),
            ),
          const SizedBox(height: 16),
        ],
        const Text(
          'Browse Categories',
          style: TextStyle(
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
            final category = _categories[index];
            return GestureDetector(
              onTap: () => onSelected(category.title),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      category.color.withValues(alpha: 0.85),
                      category.color.withValues(alpha: 0.4),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  category.title,
                  style: const TextStyle(
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
}

class _Results extends ConsumerWidget {
  const _Results({
    required this.search,
    required this.filter,
    required this.onOpened,
  });

  final SearchState search;
  final _SearchFilter filter;
  final VoidCallback onOpened;

  bool _shows(_SearchFilter section) =>
      filter == _SearchFilter.all || filter == section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!search.hasResults) {
      return EmptyView(
        icon: Icons.search_off_rounded,
        message: 'No results found for "${search.query.trim()}"',
      );
    }

    final navigator = Navigator.of(context);
    final showHeadings = filter == _SearchFilter.all;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
      children: [
        if (_shows(_SearchFilter.artists) && search.artists.isNotEmpty) ...[
          if (showHeadings) const _Heading('Artists'),
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: search.artists.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final artist = search.artists[index];
                return GestureDetector(
                  onTap: () {
                    onOpened();
                    openArtist(navigator, artist.id);
                  },
                  child: SizedBox(
                    width: 72,
                    child: Column(
                      children: [
                        ClipOval(
                          child: CoverImage(
                            url: artist.avatarUrl,
                            width: 60,
                            height: 60,
                            iconSize: 26,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          artist.name,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_shows(_SearchFilter.tracks) && search.tracks.isNotEmpty) ...[
          if (showHeadings) const _Heading('Songs'),
          for (final (index, track) in search.tracks.indexed)
            SongTile(
              track: track,
              onTap: () {
                onOpened();
                playTapped(
                  context,
                  ref,
                  track,
                  queue: search.tracks,
                  index: index,
                  playbackContext: PlaybackContext.search,
                );
              },
            ),
        ],
        if (_shows(_SearchFilter.albums) && search.albums.isNotEmpty) ...[
          if (showHeadings) const _Heading('Albums'),
          for (final album in search.albums)
            _ResultTile(
              title: album.title,
              subtitle: [
                if (album.artistName.isNotEmpty) album.artistName,
                if (album.year != null) '${album.year}',
              ].join(' • '),
              imageUrl: album.coverUrl,
              onTap: () {
                onOpened();
                openAlbum(navigator, album.id);
              },
            ),
        ],
        if (_shows(_SearchFilter.playlists) && search.playlists.isNotEmpty) ...[
          if (showHeadings) const _Heading('Playlists'),
          for (final playlist in search.playlists)
            _ResultTile(
              title: playlist.title,
              subtitle: playlist.author ?? 'Playlist',
              imageUrl: playlist.coverUrl,
              onTap: () {
                onOpened();
                openCatalogPlaylist(navigator, playlist.id);
              },
            ),
        ],
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CoverImage(url: imageUrl, width: 44, height: 44, iconSize: 22),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
      onTap: onTap,
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
