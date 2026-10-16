<div align="center">

# Liner Mobile

**Modern mobile music streaming player with syllable-synced lyrics and reactive dynamic visuals.**

[![Flutter](https://img.shields.io/badge/Flutter-3.32+-02569B?style=flat-square&logo=flutter&logoColor=black&labelColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.5+-0175C2?style=flat-square&logo=dart&logoColor=black&labelColor=white)](https://dart.dev)
[![Riverpod](https://img.shields.io/badge/Riverpod-2.6-8A2BE2?style=flat-square&logo=flutter&logoColor=black&labelColor=white)](https://riverpod.dev)
[![just_audio](https://img.shields.io/badge/just_audio-0.9-4CAF50?style=flat-square&logo=googleplay&logoColor=black&labelColor=white)](https://pub.dev/packages/just_audio)
[![Android & iOS](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-3DDC84?style=flat-square&logo=android&logoColor=black&labelColor=white)](https://flutter.dev)
[![License: Source-Available](https://img.shields.io/badge/License-Source--Available-blueviolet?style=flat-square&labelColor=white)](./LICENSE)

[Features](#features) •
[Architecture](#architecture) •
[Ecosystem Integration](#ecosystem-integration) •
[Getting Started](#getting-started) •
[Testing](#testing) •
[Building](#building) •
[Contributing](#contributing) •
[License](#license)

</div>

---

## Features
- **Syllable-Synced Lyrics**: Real-time word-level synchronized lyrics parsing matching upstream word-level specifications, with smooth active line auto-centering and instant interactive seek on tap.
- **Dynamic Visuals**: Reactive ambient mesh gradients derived from track cover art with live playback pulsing.
- **Persistent Mini Player**: Floating playback bar with quick controls, scrubbing progress indicator, and smooth slide navigation to fullscreen player.
- **Audio Control & DSP**: Pitch shifting (0.5x to 1.5x) and tempo scaling (0.5x to 2.0x) powered by `just_audio`.
- **Ecosystem Compatibility**: Universal share links (`https://link.tryliner.fun/track?id=...`), deep links (`liner://track?id=...`), and cover art failover proxy (`covers.tryliner.fun`).

---

> [!NOTE]
> Liner Mobile client connects to the official Liner API backend for music catalog, streaming playback, and synchronized lyrics.

---

## Architecture
```
liner-mobile/
├── lib/
│   ├── main.dart                      # App entry point, Riverpod ProviderScope & system UI styling
│   ├── core/
│   │   ├── api/
│   │   │   ├── api_client.dart        # Dual-endpoint failover (Cloudflare & Polish relay) with visitorData warmup
│   │   │   └── api_constants.dart     # Upstream API routes and base URLs
│   │   ├── models/
│   │   │   ├── lyric_line.dart        # Line and syllable timecode data contracts
│   │   │   └── track.dart             # Track entity with tryliner cover proxy fallback
│   │   ├── services/
│   │   │   ├── audio_handler.dart     # Background playback & lockscreen notification integration
│   │   │   └── lyric_parser.dart      # LRC & word-level syllable grouping parser
│   │   └── theme/
│   │       └── app_theme.dart         # High-contrast OLED dark theme & typography tokens
│   ├── providers/
│   │   ├── music_provider.dart        # Home catalog, query debounce & search filters
│   │   └── player_provider.dart       # Playback state machine, repeat, shuffle & speed/pitch DSP
│   └── ui/
│       ├── navigation/
│       │   └── main_navigation_shell.dart # Bottom navigation with docked mini-player
│       ├── screens/
│       │   ├── home/                  # Feed, greeting glow & pill category filters
│       │   ├── library/               # Favorites and cached tracks
│       │   ├── player/                # Fullscreen player, dynamic mesh background & lyrics view
│       │   └── settings/              # Audio settings, endpoint switch & account sheet
│       └── widgets/                   # SongTile, SongCard, MiniPlayer, DynamicMeshBackground
├── test/
│   └── widget_test.dart               # Parser and playback unit tests
├── pubspec.yaml
└── analysis_options.yaml
```

---

### Prerequisites
- **Flutter SDK** `3.32+` (Channel stable)
- **Dart SDK** `3.5+`
- Android Studio / Xcode for device deployment or emulator

---

### Setup
```bash
# 1. Clone repository
git clone https://github.com/theepar/liner-mobile.git
cd liner-mobile

# 2. Install dependencies
flutter pub get
```

---

### Running in Development
```bash
# Run on connected device or emulator
flutter run
```

---

## Testing
```bash
# Run static analysis
dart analyze lib test

# Run unit and widget test suite
flutter test
```

---

## Building
```bash
# Build Android APK (Release)
flutter build apk --release

# Build Android App Bundle (for Google Play distribution)
flutter build appbundle --release

# Build iOS application (macOS required)
flutter build ios --release
```

Compiled distributions will be placed in the `build/app/outputs/` directory.

---

## Ecosystem Integration
Liner Mobile is designed to interoperate with the official Liner ecosystem:
- **`tryliner/covers`**: Automatic fallback to `https://covers.tryliner.fun/{id}` when external CDN images are blocked or unavailable.
- **`tryliner/link`**: Handles universal links (`https://link.tryliner.fun/track?id={id}`) and custom scheme (`liner://track?id={id}`).
- **`tryliner/desktop`**: Word-level syllable grouping matching the official desktop implementation for accurate karaoke highlights.
- **Session Warmup**: YouTube visitor session data warmup (`visitorData`) to maintain reliable streaming access.

---

## Contributing
Contributions, bug fixes, and feature enhancements are welcome:

1. Fork the repository.
2. Create your feature branch (`git checkout -b feat/my-feature`).
3. Commit your changes (`git commit -m 'feat: add amazing feature'`).
4. Push to your branch (`git push origin feat/my-feature`).
5. Open a Pull Request to `theepar/liner-mobile` or the upstream project.

---

## Special Thanks
- [Liner Project Contributors](https://github.com/tryliner) — Original desktop application and architecture inspiration.
- [`just_audio`](https://pub.dev/packages/just_audio) & [`audio_service`](https://pub.dev/packages/audio_service) — High performance mobile audio playback engine.
- [Flutter Riverpod](https://riverpod.dev) — Reactive state management architecture.

---

## License
Liner Mobile is distributed under the **Liner Source-Available & Non-Commercial Contribution License**.

- **Allowed**: Personal non-commercial usage, local builds, and upstream contributions.
- **Prohibited**: Commercial distribution, public competing forks, or extracting core algorithms for third-party products.

See [LICENSE](./LICENSE) for details.
