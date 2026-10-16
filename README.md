# Liner Mobile

Mobile client for [Liner](https://github.com/tryliner): music streaming with
syllable-synced lyrics and a reactive dark UI. It talks to the same API as the
official [desktop app](https://github.com/tryliner/desktop).

[![Flutter](https://img.shields.io/badge/Flutter-3.44%2B-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![State](https://img.shields.io/badge/State-Riverpod_2-purple?style=flat-square)](https://riverpod.dev)

## Features

- **Account required.** The app opens on a sign-in / registration page; every
  screen uses data from the signed-in account.
- **Home:** recently played, daily mixes and trending tracks from the live API.
- **Search:** debounced search across songs, artists and playlists.
- **Library:** liked songs (synced with the server), your playlists, followed
  artists, and playlist creation.
- **Player:** queue, shuffle, repeat, seek, playback speed and pitch, mini
  player and fullscreen player.
- **Synced lyrics:** streamed from the lyrics endpoint; the most granular
  time-synced candidate (syllable, then word, then line) is used, with
  word-by-word karaoke highlighting and tap-to-seek.
- **Resilient networking:** automatic failover between the primary API and the
  edge relay, bearer sessions with transparent refresh-token rotation, and
  credentials kept in the platform secure storage.

## Project structure

```
lib/
├── main.dart                    # Startup, provider scope, auth gate
├── core/
│   ├── api/
│   │   ├── api_client.dart      # Dio transport: failover, sessions, refresh, SSE
│   │   └── liner_api.dart       # Typed endpoints (explore, library, search, playback, lyrics)
│   ├── config/app_config.dart   # URLs, version, timeouts
│   ├── models/                  # Track, Playlist, Artist, LinerUser, SearchResults, lyrics, player state
│   ├── theme/app_theme.dart     # Liner color tokens and Material themes
│   └── utils/                   # Lyric parser, formatters
├── services/
│   └── audio_player_service.dart  # just_audio queue and playback state
├── providers/                   # Riverpod providers (auth, player, library, search, settings)
└── ui/
    ├── navigation/              # Auth gate and bottom navigation shell
    ├── screens/                 # auth, home, search, library, player, settings
    └── widgets/                 # Shared widgets (cover image, tiles, mini player, logo)
assets/branding/                 # Official Liner logo and launcher-icon sources
test/                            # Unit, API (fake HTTP adapter) and widget tests
```

## Getting started

Requires Flutter 3.44 or newer.

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

### API server

The app talks to production (`https://api.tryliner.fun`) by default and fails
over to the edge relay automatically. To use another Liner instance, set the
equivalent of the desktop's `VITE_API_URL` at build time:

```bash
flutter run --dart-define=LINER_API_URL=https://your-instance.example
```

A custom URL disables automatic probing and failover.

The production gateway only accepts requests carrying the `x-liner-signature`,
`x-liner-timestamp` and `x-liner-nonce` headers, which the desktop app generates
with its closed-source signer. This repository does not include a signer: provide
an authorized `RequestSigner` (see `lib/core/api/request_signer.dart`) and install
it with `ApiClient.instance.signer` in `main()`. Until then, sign-in fails with
"The Liner server rejected this app".

### Launcher icons

The icons are generated from the official Liner logo in `assets/branding/`:

```bash
dart run flutter_launcher_icons
```

### Android release signing

Create `android/key.properties` (git-ignored) to sign release builds:

```properties
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

Without it, release builds fall back to the debug key so `flutter run --release`
keeps working.

## Branding and licensing

The Liner name, logo and API belong to the Liner project. The upstream
[`tryliner/desktop` license](https://github.com/tryliner/desktop/blob/main/LICENSE)
is source-available and non-commercial, does not grant rights to Liner branding,
and restricts public distribution of derivatives. Get written permission from
the maintainers before publishing builds of this app.
