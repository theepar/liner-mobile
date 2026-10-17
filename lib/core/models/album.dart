import '../config/app_config.dart';
import 'json_helpers.dart';
import 'track.dart';

class Album {
  const Album({
    required this.id,
    required this.title,
    this.artists = const [],
    this.year,
    this.coverUrl = '',
    this.trackCount,
    this.durationMs,
    this.tracks = const [],
  });

  factory Album.fromJson(JsonMap json) {
    final id = json['id']?.toString() ?? '';
    final title = asString(json['title']) ?? 'Untitled Album';
    final cover = asMap(json['cover']);
    final coverUrl = asString(cover?['url']) ?? '';
    final coverFallback = asString(cover?['fallbackUrl']);
    return Album(
      id: id,
      title: title,
      artists: parseList(json['artists'], TrackArtist.fromJson),
      year: asInt(json['year']),
      coverUrl: coverUrl,
      trackCount: asInt(json['trackCount']) ?? asInt(json['totalTracks']),
      durationMs: asInt(json['durationMs']),
      tracks: [
        for (final track in parseList(json['tracks'], Track.fromJson))
          track.copyWith(
            albumId: track.albumId ?? id,
            albumName: track.albumName ?? title,
            coverUrl: track.coverUrl.isEmpty ? coverUrl : null,
            coverFallbackUrl: track.coverUrl.isEmpty ? coverFallback : null,
          ),
      ],
    );
  }

  final String id;
  final String title;
  final List<TrackArtist> artists;
  final int? year;
  final String coverUrl;
  final int? trackCount;
  final int? durationMs;
  final List<Track> tracks;

  String get artistName => artists.map((artist) => artist.name).join(', ');

  String get shareUrl => AppConfig.shareUrl('album', id);
  String get deepLink => AppConfig.deepLink('album', id);
}
