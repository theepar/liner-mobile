import 'package:flutter/material.dart';

import '../screens/artist/artist_screen.dart';
import '../screens/collection/album_screen.dart';
import '../screens/collection/catalog_playlist_screen.dart';
import '../screens/collection/user_playlist_screen.dart';

Future<void> openArtist(NavigatorState navigator, String artistId) =>
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => ArtistScreen(artistId: artistId)),
    );

Future<void> openAlbum(NavigatorState navigator, String albumId) =>
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => AlbumScreen(albumId: albumId)),
    );

Future<void> openCatalogPlaylist(NavigatorState navigator, String playlistId) =>
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => CatalogPlaylistScreen(playlistId: playlistId),
      ),
    );

Future<void> openUserPlaylist(NavigatorState navigator, String playlistId) =>
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => UserPlaylistScreen(playlistId: playlistId),
      ),
    );
