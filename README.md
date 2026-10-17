<div align="center">

# Liner Mobile

**A Flutter music-streaming client with synchronized lyrics, a responsive player, and a dark Liner experience.**

[![Flutter](https://img.shields.io/badge/Flutter-3.44%2B-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12-0175C2?style=flat-square&logo=dart&logoColor=white)](https://dart.dev)
[![Riverpod](https://img.shields.io/badge/State-Riverpod_2-7B61FF?style=flat-square)](https://riverpod.dev)
[![just_audio](https://img.shields.io/badge/Audio-just__audio-1DB954?style=flat-square)](https://pub.dev/packages/just_audio)
[![License: Source-Available](https://img.shields.io/badge/License-Source--Available-blueviolet?style=flat-square&labelColor=white)](./LICENSE)

[Overview](#overview) •
[Architecture](#architecture) •
[Getting Started](#getting-started) •
[Testing](#testing) •
[Building](#building) •
[License](#license)

<br/>

<img src="./assets/branding/app_icon.png" alt="Liner Mobile app icon" width="160" />

</div>

---

## Overview

Liner Mobile connects to the Liner API for account data, music discovery,
library management, streaming playback, and synchronized lyrics. It requires an
account: signed-out users only see the login screen.

### Included

- Home with popular tracks, listening history, and daily mixes from the API.
- Search for tracks, artists, albums, and playlists.
- Synced library for liked tracks, followed artists, and user playlists.
- Queue controls, shuffle, repeat, seek, speed, pitch, mini player, and fullscreen player.
- Streamed lyrics with provider selection, karaoke-style word highlighting, timing offset, and tap-to-seek.
- Refresh-token sessions, secure local storage, server-time sync, and primary-to-edge API failover.

> [!WARNING]
> The production API requires authorized gateway-signature headers on every
> `/v1/*` request. This repository deliberately does not include or recreate
> the desktop signer, so production sign-in remains blocked until an authorized
> `RequestSigner` is installed before `runApp`.

---

## Architecture

```text
liner-mobile/
├── lib/
│   ├── core/
│   │   ├── api/                 # Dio transport, API endpoints, signing hook
│   │   ├── config/              # URLs, versions, and timeouts
│   │   ├── models/              # Defensive API contracts and player state
│   │   └── utils/               # Lyrics parsing, validation, formatting
│   ├── providers/               # Riverpod auth, library, search, settings, player state
│   ├── services/                # Audio engine, telemetry, lyrics, deep links
│   ├── ui/
│   │   ├── navigation/          # Auth gate and signed-in shell
│   │   ├── screens/             # Auth, home, search, library, player, settings
│   │   └── widgets/             # Reusable Liner UI components
│   └── main.dart                # App startup and provider scope
├── assets/branding/             # Liner logos and launcher-icon sources
├── test/                        # Unit, API, provider, and widget tests
├── android/                     # Android runner and release configuration
├── ios/                         # iOS runner configuration
└── pubspec.yaml                 # Flutter packages and application metadata
```

---

## Getting Started

### Prerequisites

- Flutter `3.44+`
- Dart `3.12+` (bundled with Flutter)
- An Android emulator/device or an iOS simulator/device

### Setup

```bash
# 1. Clone the repository
git clone https://github.com/theepar/liner-mobile.git
cd liner-mobile

# 2. Install packages
flutter pub get
```

### Run in Development

```bash
# Use the production API configuration
flutter run

# Or use an authorized custom Liner API instance
flutter run --dart-define=LINER_API_URL=https://your-instance.example
```

A custom `LINER_API_URL` disables endpoint probing and failover. Covers are
served by the API response's `cover.url` or `cover.fallbackUrl`; the desktop
covers proxy is not used.

### Authorized API Signer

Install an authorized implementation before `runApp`:

```dart
ApiClient.instance.signer = authorizedSigner;
```

`RequestSigner` receives the exact serialized JSON body, request method, path,
and server-adjusted timestamp required by the API gateway. Do not extract or
imitate the desktop signer.

---

## Testing

```bash
# Format source and tests
dart format lib test

# Static analysis (must remain at zero issues)
flutter analyze

# Unit, API, provider, and widget tests
flutter test
```

---

## Building

```bash
# Android release APK
flutter build apk --release

# Regenerate launcher icons after branding changes
dart run flutter_launcher_icons
```

To sign Android releases, create the git-ignored `android/key.properties`:

```properties
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

---

## Current Limitations

- Background playback, media notifications and lock-screen controls are
  configured for Android and iOS; physical-device validation is still pending.
- Deep links are parsed in-app, but device-level Android/iOS verification is pending.
- The edge relay fallback uses HTTP; do not rely on it for sensitive credentials.
- The app has no bundled `RequestSigner`, so the production gateway rejects sign-in.

---

## License

Liner Mobile is distributed under the **Liner Source-Available & Non-Commercial Contribution License**.

- **Allowed:** personal non-commercial use, local builds, and upstream contributions.
- **Prohibited:** commercial distribution, public competing forks, and extraction of protected algorithms.

See [LICENSE](./LICENSE) for the full terms. Liner branding and the Liner API
remain subject to the upstream project's permissions and restrictions.
