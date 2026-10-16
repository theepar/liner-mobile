import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/artist.dart';
import '../../../core/models/playlist.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/api_provider.dart';
import '../../../providers/library_provider.dart';
import '../../../providers/player_provider.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/song_tile.dart';
import '../../widgets/status_views.dart';

enum _LibraryTab {
  all('All'),
  liked('Liked Songs'),
  playlists('Playlists'),
  artists('Artists');

  const _LibraryTab(this.label);

  final String label;
}

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  _LibraryTab _tab = _LibraryTab.all;

  bool _shows(_LibraryTab tab) => _tab == _LibraryTab.all || _tab == tab;

  Future<void> _createPlaylist() async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => const _CreatePlaylistDialog(),
    );
    if (title == null || !mounted) return;
    try {
      await ref.read(linerApiProvider).createPlaylist(title);
      ref.invalidate(userPlaylistsProvider);
    } on ApiException {
      if (mounted) showMessage(context, 'Could not create the playlist.');
    }
  }

  Future<void> _playPlaylist(Playlist playlist) async {
    try {
      final tracks = await ref
          .read(linerApiProvider)
          .getPlaylistTracks(playlist.id);
      if (!mounted) return;
      if (tracks.isEmpty) {
        showMessage(context, 'This playlist is empty.');
        return;
      }
      await ref.read(playerStateProvider.notifier).playAll(tracks);
    } on ApiException {
      if (mounted) showMessage(context, 'Could not load the playlist.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final liked = ref.watch(likedTracksProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Your Library',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                      letterSpacing: -0.5,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    tooltip: 'New playlist',
                    icon: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: _createPlaylist,
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (final tab in _LibraryTab.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _TabChip(
                        label: tab.label,
                        isSelected: tab == _tab,
                        onSelected: () => setState(() => _tab = tab),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  if (_shows(_LibraryTab.liked))
                    _LikedHero(
                      count: liked.ids.length,
                      onPlay: () => ref
                          .read(playerStateProvider.notifier)
                          .playAll(liked.tracks),
                    ),
                  if (_shows(_LibraryTab.playlists)) ...[
                    const _ListTitle('Playlists'),
                    _PlaylistsSection(onPlay: _playPlaylist),
                    const SizedBox(height: 16),
                  ],
                  if (_shows(_LibraryTab.artists)) ...[
                    const _ListTitle('Followed Artists'),
                    const _ArtistsSection(),
                  ],
                  if (_tab == _LibraryTab.liked) _LikedTracksList(state: liked),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
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
          color: isSelected
              ? Colors.transparent
              : LinerColors.darkBorderSecondary,
        ),
      ),
      onSelected: (_) => onSelected(),
    );
  }
}

class _ListTitle extends StatelessWidget {
  const _ListTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 17,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _LikedHero extends StatelessWidget {
  const _LikedHero({required this.count, required this.onPlay});

  final int count;
  final VoidCallback onPlay;

  static const _gradient = [Color(0xFF831843), Color(0xFF1E1B4B)];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GestureDetector(
        onTap: onPlay,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: _gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _gradient.first.withValues(alpha: 0.3),
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
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: LinerColors.accentPrimary,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Liked Songs',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$count liked ${count == 1 ? 'track' : 'tracks'}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.7),
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
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistsSection extends ConsumerWidget {
  const _PlaylistsSection({required this.onPlay});

  final ValueChanged<Playlist> onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(userPlaylistsProvider)
        .when(
          loading: () => const LoadingView(),
          error: (_, _) => ErrorRetry(
            message: "Couldn't load your playlists.",
            onRetry: () => ref.invalidate(userPlaylistsProvider),
          ),
          data: (playlists) {
            if (playlists.isEmpty) {
              return const EmptyView(
                icon: Icons.queue_music_rounded,
                message: 'No playlists yet. Tap + to create one.',
              );
            }
            return Column(
              children: [
                for (final playlist in playlists)
                  _LibraryTile(
                    title: playlist.title,
                    subtitle: playlist.description ?? 'Playlist',
                    imageUrl: playlist.coverUrl,
                    onTap: () => onPlay(playlist),
                  ),
              ],
            );
          },
        );
  }
}

class _ArtistsSection extends ConsumerWidget {
  const _ArtistsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(followedArtistsProvider)
        .when(
          loading: () => const LoadingView(),
          error: (_, _) => ErrorRetry(
            message: "Couldn't load your followed artists.",
            onRetry: () => ref.invalidate(followedArtistsProvider),
          ),
          data: (List<Artist> artists) {
            if (artists.isEmpty) {
              return const EmptyView(
                icon: Icons.person_outline_rounded,
                message: 'You are not following any artists yet.',
              );
            }
            return Column(
              children: [
                for (final artist in artists)
                  _LibraryTile(
                    title: artist.name,
                    subtitle: 'Artist',
                    imageUrl: artist.avatarUrl,
                    isCircular: true,
                  ),
              ],
            );
          },
        );
  }
}

class _LikedTracksList extends ConsumerWidget {
  const _LikedTracksList({required this.state});

  final LikedTracksState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading) return const LoadingView();
    if (state.hasError) {
      return ErrorRetry(
        message: "Couldn't load your liked songs.",
        onRetry: () => ref.read(likedTracksProvider.notifier).refresh(),
      );
    }
    if (state.tracks.isEmpty) {
      return const EmptyView(
        icon: Icons.favorite_border_rounded,
        message: 'Songs you like will show up here.',
      );
    }
    final player = ref.read(playerStateProvider.notifier);
    return Column(
      children: [
        for (final (index, track) in state.tracks.indexed)
          SongTile(
            track: track,
            onTap: () => player.playTrack(track, state.tracks, index),
          ),
      ],
    );
  }
}

class _LibraryTile extends StatelessWidget {
  const _LibraryTile({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.onTap,
    this.isCircular = false,
  });

  final String title;
  final String subtitle;
  final String imageUrl;
  final VoidCallback? onTap;
  final bool isCircular;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(isCircular ? 24 : 8),
        child: CoverImage(url: imageUrl, width: 48, height: 48, iconSize: 22),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.white,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      trailing: onTap == null
          ? null
          : const Icon(Icons.play_arrow_rounded, color: Colors.white38),
      onTap: onTap,
    );
  }
}

class _CreatePlaylistDialog extends StatefulWidget {
  const _CreatePlaylistDialog();

  @override
  State<_CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<_CreatePlaylistDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _controller.text.trim();
    if (title.isNotEmpty) Navigator.of(context).pop(title);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: LinerColors.darkElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'New Playlist',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Playlist name',
          hintStyle: TextStyle(color: Colors.white38),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: LinerColors.accentPrimary,
            foregroundColor: Colors.white,
          ),
          onPressed: _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
