import '../config/app_config.dart';
import 'album.dart';
import 'json_helpers.dart';
import 'track.dart';

/// The full artist page: profile plus top tracks, albums and singles.
class ArtistDetails {
  const ArtistDetails({
    required this.id,
    required this.name,
    this.avatarUrl = '',
    this.bio,
    this.monthlyListeners,
    this.verified = false,
    this.tracks = const [],
    this.albums = const [],
    this.singles = const [],
  });

  factory ArtistDetails.fromJson(JsonMap json) => ArtistDetails(
    id: json['id']?.toString() ?? '',
    name: asString(json['name']) ?? 'Unknown Artist',
    avatarUrl: asString(asMap(json['cover'])?['url']) ?? '',
    bio: asString(json['bio']),
    monthlyListeners: json['monthlyListeners']?.toString(),
    verified: asBool(json['verified']) ?? false,
    tracks: parseList(json['tracks'], Track.fromJson),
    albums: parseList(json['albums'], Album.fromJson),
    singles: parseList(json['singles'], Album.fromJson),
  );

  final String id;
  final String name;
  final String avatarUrl;
  final String? bio;

  /// Display text from the API, for example "12.3M".
  final String? monthlyListeners;
  final bool verified;
  final List<Track> tracks;
  final List<Album> albums;
  final List<Album> singles;

  String get shareUrl => AppConfig.shareUrl('artist', id);
  String get deepLink => AppConfig.deepLink('artist', id);
}
