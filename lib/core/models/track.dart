import '../config/app_config.dart';
import '../utils/formatters.dart';
import 'json_helpers.dart';

class TrackArtist {
  const TrackArtist({required this.id, required this.name});

  factory TrackArtist.fromJson(JsonMap json) => TrackArtist(
    id: json['id']?.toString() ?? '',
    name: asString(json['name']) ?? 'Unknown Artist',
  );

  final String id;
  final String name;
}

class Track {
  const Track({
    required this.id,
    required this.title,
    this.artists = const [],
    this.albumId,
    this.albumName,
    this.coverUrl = '',
    this.coverFallbackUrl,
    this.durationMs = 0,
    this.explicit = false,
  });

  factory Track.fromJson(JsonMap json) {
    final album = asMap(json['album']);
    final cover = asMap(json['cover']);
    return Track(
      id: json['id']?.toString() ?? '',
      title: asString(json['title']) ?? 'Untitled Track',
      artists: parseList(json['artists'], TrackArtist.fromJson),
      albumId: album?['id']?.toString(),
      albumName: asString(album?['title']),
      coverUrl: asString(cover?['url']) ?? '',
      coverFallbackUrl: asString(cover?['fallbackUrl']),
      durationMs: asInt(json['durationMs']) ?? 0,
      explicit: asBool(json['explicit']) ?? false,
    );
  }

  final String id;
  final String title;
  final List<TrackArtist> artists;
  final String? albumId;
  final String? albumName;
  final String coverUrl;
  final String? coverFallbackUrl;
  final int durationMs;
  final bool explicit;

  String get artistName => artists.isEmpty
      ? 'Unknown Artist'
      : artists.map((a) => a.name).join(', ');

  String? get artistId => artists.isEmpty ? null : artists.first.id;

  String get shareUrl => AppConfig.shareUrl('track', id);
  String get deepLink => AppConfig.deepLink('track', id);

  String get durationFormatted =>
      formatDuration(Duration(milliseconds: durationMs));
}
