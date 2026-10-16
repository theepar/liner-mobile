import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/album.dart';
import '../../../core/models/artist_details.dart';
import '../../../core/models/collection_type.dart';
import '../../../core/models/playback_event.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/library_provider.dart';
import '../../navigation/navigation_helpers.dart';
import '../../widgets/collection_header.dart';
import '../../widgets/detail_scaffold.dart';
import '../../widgets/save_button.dart';
import '../../widgets/song_card.dart';

class ArtistScreen extends ConsumerWidget {
  const ArtistScreen({super.key, required this.artistId});

  final String artistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DetailScaffold(
      body: detailBody(
        ref.watch(artistDetailsProvider(artistId)),
        errorMessage: "Couldn't load this artist.",
        onRetry: () => ref.invalidate(artistDetailsProvider(artistId)),
        builder: (artist) => _ArtistBody(artist: artist),
      ),
    );
  }
}

class _ArtistBody extends StatelessWidget {
  const _ArtistBody({required this.artist});

  final ArtistDetails artist;

  @override
  Widget build(BuildContext context) {
    final playbackContext = PlaybackContext('artist', artist.id);
    final listeners = artist.monthlyListeners;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        CollectionHeader(
          title: artist.name,
          coverUrl: artist.avatarUrl,
          isCircular: true,
          subtitle: listeners == null || listeners.isEmpty
              ? null
              : '$listeners monthly listeners',
          description: artist.bio,
          titleBadge: artist.verified
              ? const Icon(
                  Icons.verified_rounded,
                  color: LinerColors.accentPrimary,
                  size: 20,
                )
              : null,
          actions: [
            PlayActions(
              tracks: artist.tracks,
              playbackContext: playbackContext,
            ),
            SaveButton(type: CollectionType.artists, id: artist.id),
          ],
        ),
        if (artist.tracks.isNotEmpty) ...[
          const _SectionTitle('Popular'),
          TrackRows(
            tracks: artist.tracks.take(10).toList(),
            playbackContext: playbackContext,
            showRank: true,
          ),
        ],
        if (artist.albums.isNotEmpty) ...[
          const _SectionTitle('Albums'),
          _ReleaseRow(releases: artist.albums),
        ],
        if (artist.singles.isNotEmpty) ...[
          const _SectionTitle('Singles & EPs'),
          _ReleaseRow(releases: artist.singles),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _ReleaseRow extends StatelessWidget {
  const _ReleaseRow({required this.releases});

  final List<Album> releases;

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: releases.length,
        itemBuilder: (context, index) {
          final release = releases[index];
          return SongCard(
            title: release.title,
            subtitle: release.year?.toString(),
            imageUrl: release.coverUrl,
            onTap: () => openAlbum(navigator, release.id),
          );
        },
      ),
    );
  }
}
