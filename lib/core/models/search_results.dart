import 'artist.dart';
import 'json_helpers.dart';
import 'playlist.dart';
import 'track.dart';

class SearchResults {
  const SearchResults({
    this.tracks = const [],
    this.artists = const [],
    this.playlists = const [],
  });

  /// The API returns one heterogeneous `items` list discriminated by `type`.
  /// Albums are not surfaced by the mobile UI yet and are skipped.
  factory SearchResults.fromJson(JsonMap json) {
    final tracks = <Track>[];
    final artists = <Artist>[];
    final playlists = <Playlist>[];
    for (final item in parseList(json['items'], (item) => item)) {
      switch (asString(item['type'])) {
        case 'track':
          tracks.add(Track.fromJson(item));
        case 'artist':
          artists.add(Artist.fromJson(item));
        case 'playlist':
          playlists.add(Playlist.fromJson(item));
      }
    }
    return SearchResults(
      tracks: tracks,
      artists: artists,
      playlists: playlists,
    );
  }

  static const empty = SearchResults();

  final List<Track> tracks;
  final List<Artist> artists;
  final List<Playlist> playlists;

  bool get isEmpty => tracks.isEmpty && artists.isEmpty && playlists.isEmpty;
}
