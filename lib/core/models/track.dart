class Track {
  final String id;
  final String title;
  final String artistName;
  final String? artistId;
  final String? albumName;
  final String? albumId;
  final String coverUrl;
  final int durationMs;
  final int playCount;
  final bool hasLyrics;
  final bool explicit;
  final String? streamUrl;

  const Track({
    required this.id,
    required this.title,
    required this.artistName,
    this.artistId,
    this.albumName,
    this.albumId,
    required this.coverUrl,
    this.durationMs = 0,
    this.playCount = 0,
    this.hasLyrics = true,
    this.explicit = false,
    this.streamUrl,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    // Artist extraction
    String artist = 'Unknown Artist';
    String? aId;
    if (json['artist'] is Map<String, dynamic>) {
      artist = json['artist']['name']?.toString() ?? artist;
      aId = json['artist']['id']?.toString();
    } else if (json['artists'] is String && (json['artists'] as String).isNotEmpty) {
      artist = json['artists'] as String;
    } else if (json['artist'] is String && (json['artist'] as String).isNotEmpty) {
      artist = json['artist'] as String;
    }

    // Album extraction
    String? album;
    String? alId;
    if (json['album'] is Map<String, dynamic>) {
      album = json['album']['title']?.toString() ?? json['album']['name']?.toString();
      alId = json['album']['id']?.toString();
    } else if (json['album'] is String) {
      album = json['album'] as String;
    }

    // Cover URL
    String cover = '';
    if (json['cover'] is Map<String, dynamic>) {
      cover = json['cover']['url']?.toString() ?? '';
    } else if (json['cover'] is String) {
      cover = json['cover'] as String;
    } else if (json['cover_url'] is String) {
      cover = json['cover_url'] as String;
    } else if (json['coverUrl'] is String) {
      cover = json['coverUrl'] as String;
    }

    return Track(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? 'Untitled Track',
      artistName: artist,
      artistId: aId,
      albumName: album,
      albumId: alId,
      coverUrl: cover.isNotEmpty
          ? cover
          : 'https://images.unsplash.com/photo-1614613535308-eb5fbd3d2c17?w=600&auto=format&fit=crop&q=80',
      durationMs: (json['durationMs'] ?? json['duration_ms'] as num?)?.toInt() ?? 0,
      playCount: (json['playCount'] ?? json['play_count'] as num?)?.toInt() ?? 0,
      hasLyrics: json['has_lyrics'] as bool? ?? json['hasLyrics'] as bool? ?? true,
      explicit: json['explicit'] as bool? ?? false,
      streamUrl: json['streamUrl'] as String? ?? json['stream_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artistName,
        'artistId': artistId,
        'album': albumName,
        'albumId': albumId,
        'coverUrl': coverUrl,
        'durationMs': durationMs,
        'playCount': playCount,
        'hasLyrics': hasLyrics,
        'explicit': explicit,
        'streamUrl': streamUrl,
      };

  Track copyWith({
    String? id,
    String? title,
    String? artistName,
    String? artistId,
    String? albumName,
    String? albumId,
    String? coverUrl,
    int? durationMs,
    int? playCount,
    bool? hasLyrics,
    bool? explicit,
    String? streamUrl,
  }) =>
      Track(
        id: id ?? this.id,
        title: title ?? this.title,
        artistName: artistName ?? this.artistName,
        artistId: artistId ?? this.artistId,
        albumName: albumName ?? this.albumName,
        albumId: albumId ?? this.albumId,
        coverUrl: coverUrl ?? this.coverUrl,
        durationMs: durationMs ?? this.durationMs,
        playCount: playCount ?? this.playCount,
        hasLyrics: hasLyrics ?? this.hasLyrics,
        explicit: explicit ?? this.explicit,
        streamUrl: streamUrl ?? this.streamUrl,
      );

  String get durationFormatted {
    final total = durationMs ~/ 1000;
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String get playCountFormatted {
    if (playCount >= 1000000) {
      return '${(playCount / 1000000).toStringAsFixed(1)}M';
    } else if (playCount >= 1000) {
      return '${(playCount / 1000).toStringAsFixed(1)}K';
    }
    return playCount.toString();
  }
}

class Playlist {
  final String id;
  final String name;
  final String? description;
  final String coverUrl;
  final int trackCount;
  final List<Track> tracks;

  const Playlist({
    required this.id,
    required this.name,
    this.description,
    required this.coverUrl,
    this.trackCount = 0,
    this.tracks = const [],
  });

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        id: json['id']?.toString() ?? '',
        name: json['name'] as String? ?? json['title'] as String? ?? 'Untitled Playlist',
        description: json['description'] as String?,
        coverUrl: json['cover_url'] as String? ??
            json['coverUrl'] as String? ??
            'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&auto=format&fit=crop&q=80',
        trackCount: (json['track_count'] ?? json['totalTracks'] as num?)?.toInt() ?? 0,
        tracks: (json['tracks'] as List<dynamic>?)
                ?.map((t) => Track.fromJson(t as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

class Artist {
  final String id;
  final String name;
  final String avatarUrl;
  final int monthlyListeners;
  final String? description;

  const Artist({
    required this.id,
    required this.name,
    required this.avatarUrl,
    this.monthlyListeners = 0,
    this.description,
  });

  factory Artist.fromJson(Map<String, dynamic> json) => Artist(
        id: json['id']?.toString() ?? '',
        name: json['name'] as String? ?? 'Unknown Artist',
        avatarUrl: json['avatar_url'] as String? ??
            json['imageUrl'] as String? ??
            'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=600&auto=format&fit=crop&q=80',
        monthlyListeners: (json['monthly_listeners'] ?? json['followers'] as num?)?.toInt() ?? 0,
        description: json['description'] as String?,
      );

  String get listenersFormatted {
    if (monthlyListeners >= 1000000) {
      return '${(monthlyListeners / 1000000).toStringAsFixed(1)}M monthly listeners';
    } else if (monthlyListeners >= 1000) {
      return '${(monthlyListeners / 1000).toStringAsFixed(1)}K monthly listeners';
    }
    return '$monthlyListeners monthly listeners';
  }
}

class LyricLine {
  final int startMs;
  final int endMs;
  final String text;
  final List<LyricWord> words;
  final bool isInstrumental;

  const LyricLine({
    required this.startMs,
    required this.endMs,
    required this.text,
    this.words = const [],
    this.isInstrumental = false,
  });

  factory LyricLine.fromJson(Map<String, dynamic> json) => LyricLine(
        startMs: (json['start_ms'] ?? json['timeMs'] as num?)?.toInt() ?? 0,
        endMs: (json['end_ms'] as num?)?.toInt() ?? 0,
        text: json['text'] as String? ?? '',
        words: (json['words'] as List<dynamic>?)
                ?.map((w) => LyricWord.fromJson(w as Map<String, dynamic>))
                .toList() ??
            const [],
        isInstrumental: json['isInstrumental'] as bool? ?? false,
      );
}

class LyricWord {
  final int startMs;
  final int endMs;
  final String text;

  const LyricWord({
    required this.startMs,
    required this.endMs,
    required this.text,
  });

  factory LyricWord.fromJson(Map<String, dynamic> json) => LyricWord(
        startMs: (json['start_ms'] ?? json['timeMs'] as num?)?.toInt() ?? 0,
        endMs: (json['end_ms'] ?? json['endMs'] as num?)?.toInt() ?? 0,
        text: json['text'] as String? ?? '',
      );
}
