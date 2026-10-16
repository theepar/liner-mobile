import '../config/app_config.dart';
import 'json_helpers.dart';
import 'track.dart';

/// Catalog playlists, user playlists and daily mixes share this shape; fields
/// a given endpoint does not provide stay empty or null.
class Playlist {
  const Playlist({
    required this.id,
    required this.title,
    this.description,
    this.author,
    this.coverUrl = '',
    this.trackCount,
    this.tracks = const [],
  });

  factory Playlist.fromJson(JsonMap json) => Playlist(
    id: json['id']?.toString() ?? '',
    title: asString(json['title']) ?? 'Untitled Playlist',
    description: asString(json['description']),
    author: asString(json['author']),
    coverUrl: asString(asMap(json['cover'])?['url']) ?? '',
    trackCount: asInt(json['trackCount']),
    tracks: parseList(json['tracks'], Track.fromJson),
  );

  final String id;
  final String title;
  final String? description;
  final String? author;
  final String coverUrl;
  final int? trackCount;
  final List<Track> tracks;

  String get shareUrl => AppConfig.shareUrl('playlist', id);
  String get deepLink => AppConfig.deepLink('playlist', id);
}

/// A track inside one of the user's playlists; [id] identifies the entry (not
/// the track) for removal.
class PlaylistItem {
  const PlaylistItem({required this.id, required this.track});

  static PlaylistItem? tryParse(Object? value) {
    final json = asMap(value);
    final track = asMap(json?['track']);
    if (json == null || track == null) return null;
    return PlaylistItem(
      id: json['id']?.toString() ?? '',
      track: Track.fromJson(track),
    );
  }

  final String id;
  final Track track;
}

class UserPlaylistDetails {
  const UserPlaylistDetails({required this.playlist, required this.items});

  factory UserPlaylistDetails.fromJson(JsonMap json) => UserPlaylistDetails(
    playlist: Playlist.fromJson(asMap(json['playlist']) ?? const {}),
    items: [
      for (final item in asList(json['items']) ?? const <Object?>[])
        ?PlaylistItem.tryParse(item),
    ],
  );

  final Playlist playlist;
  final List<PlaylistItem> items;

  List<Track> get tracks => [for (final item in items) item.track];
}
