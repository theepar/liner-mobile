/// Services playlists can be imported from.
abstract final class ImportSources {
  static const supportedHint =
      'Paste a link from YouTube, SoundCloud, Spotify, Deezer or Apple Music';

  /// Adds the scheme when missing and returns null for anything that is not a
  /// usable web address.
  static Uri? normalize(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;
    if (!text.startsWith('http://') && !text.startsWith('https://')) {
      text = 'https://$text';
    }
    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty || !uri.host.contains('.')) {
      return null;
    }
    return uri;
  }

  /// A display name for the service a link belongs to, or null if unknown.
  static String? detect(String raw) {
    final host = normalize(raw)?.host.toLowerCase().replaceFirst('www.', '');
    if (host == null) return null;
    if (const {
      'youtube.com',
      'music.youtube.com',
      'm.youtube.com',
      'youtu.be',
    }.contains(host)) {
      return 'YouTube';
    }
    if (host == 'soundcloud.com' || host.endsWith('.soundcloud.com')) {
      return 'SoundCloud';
    }
    if (host == 'open.spotify.com') return 'Spotify';
    if (host == 'deezer.com' || host.endsWith('.deezer.com')) return 'Deezer';
    if (const {
          'music.apple.com',
          'geo.music.apple.com',
          'itunes.apple.com',
        }.contains(host) ||
        host.endsWith('.music.apple.com')) {
      return 'Apple Music';
    }
    return null;
  }

  /// The SoundCloud likes page for a username, or the link itself when a full
  /// address was given.
  static String soundCloudLikesUrl(String usernameOrUrl) {
    final value = usernameOrUrl.trim().replaceFirst(RegExp('^@'), '');
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return 'https://soundcloud.com/${Uri.encodeComponent(value)}/likes';
  }
}

abstract final class PlaylistRules {
  static const titleMaxLength = 20;
  static const descriptionMaxLength = 300;
}
