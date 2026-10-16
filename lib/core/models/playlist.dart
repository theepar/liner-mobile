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
