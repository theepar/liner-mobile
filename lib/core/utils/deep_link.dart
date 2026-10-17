import '../config/app_config.dart';

enum DeepLinkType { artist, album, playlist, track }

class DeepLinkTarget {
  const DeepLinkTarget(this.type, this.id);

  final DeepLinkType type;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is DeepLinkTarget && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);

  @override
  String toString() => 'DeepLinkTarget(${type.name}, $id)';
}

abstract final class DeepLinks {
  static final _idPatterns = {
    DeepLinkType.artist: RegExp(r'^UC[A-Za-z0-9_-]{22}$'),
    DeepLinkType.album: RegExp(r'^MPRE[A-Za-z0-9_-]{4,64}$'),
    DeepLinkType.playlist: RegExp(r'^[A-Za-z0-9_-]{8,64}$'),
    DeepLinkType.track: RegExp(r'^[A-Za-z0-9_-]{11}$'),
  };

  static final _userPlaylistId = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static DeepLinkTarget? parse(Uri uri) {
    if (uri.scheme != AppConfig.deepLinkScheme) return null;

    final type = DeepLinkType.values
        .where((candidate) => candidate.name == uri.host)
        .firstOrNull;
    if (type == null) return null;

    final ids = uri.queryParametersAll['id'];
    if (ids == null || ids.length != 1) return null;
    final id = ids.single;
    if (!_idPatterns[type]!.hasMatch(id)) return null;

    return DeepLinkTarget(type, id);
  }

  static bool isUserPlaylistId(String id) =>
      id.startsWith('pl-') || _userPlaylistId.hasMatch(id);
}
