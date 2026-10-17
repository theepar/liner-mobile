enum CollectionType {
  albums('albums', 'album'),
  artists('artists', 'artist'),
  playlists('playlists', 'playlist');

  const CollectionType(this.path, this.entryKey);

  final String path;

  final String entryKey;
}
