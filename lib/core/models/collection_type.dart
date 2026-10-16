/// What the user can save to their library besides liked tracks.
enum CollectionType {
  albums('albums', 'album'),
  artists('artists', 'artist'),
  playlists('playlists', 'playlist');

  const CollectionType(this.path, this.entryKey);

  /// Path segment under `/v1/me/library/`.
  final String path;

  /// Key holding the item inside each saved entry.
  final String entryKey;
}
