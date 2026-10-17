import 'album.dart';
import 'artist.dart';
import 'json_helpers.dart';
import 'playlist.dart';
import 'track.dart';

class SearchResults {
  const SearchResults({
    this.tracks = const [],
    this.artists = const [],
    this.albums = const [],
    this.playlists = const [],
  });

  factory SearchResults.fromJson(JsonMap json) {
    final tracks = <Track>[];
    final artists = <Artist>[];
    final albums = <Album>[];
    final playlists = <Playlist>[];
    for (final item in parseList(json['items'], (item) => item)) {
      switch (asString(item['type'])) {
        case 'track':
          tracks.add(Track.fromJson(item));
        case 'artist':
          artists.add(Artist.fromJson(item));
        case 'album':
          albums.add(Album.fromJson(item));
        case 'playlist':
          playlists.add(Playlist.fromJson(item));
      }
    }
    return SearchResults(
      tracks: tracks,
      artists: artists,
      albums: albums,
      playlists: playlists,
    );
  }

  static const empty = SearchResults();

  final List<Track> tracks;
  final List<Artist> artists;
  final List<Album> albums;
  final List<Playlist> playlists;

  bool get isEmpty =>
      tracks.isEmpty && artists.isEmpty && albums.isEmpty && playlists.isEmpty;
}
