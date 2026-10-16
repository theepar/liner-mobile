# Liner Mobile 🎵

<div align="center">

**Modern mobile music streaming client with syllable-synced lyrics and reactive dynamic visuals.**  
*Adapted for mobile UX from the official [Liner Desktop](https://github.com/tryliner/desktop).*

[![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13-0175C2?style=flat-square&logo=dart&logoColor=white)](https://dart.dev)
[![State](https://img.shields.io/badge/State-Riverpod_2.6-purple?style=flat-square)](https://riverpod.dev)
[![License: Source-Available](https://img.shields.io/badge/License-Source--Available-blueviolet?style=flat-square)](./LICENSE)

</div>

---

## ✨ Features

- **Syllable-Synced & Line-Synced Lyrics (Liner's signature feature)**:
  - Real-time word-level karaoke highlighting using exact millisecond timing.
  - Interactive auto-scrolling with smooth easing to keep the active line centered.
  - Tap on any lyric line to instantly seek audio to that timestamp.
- **Reactive Dynamic Visuals**:
  - Animated ambient gradient mesh background derived from album cover art.
  - Reacts smoothly to playback state (subtle pulsing glow).
- **Time-of-Day Ambient Header**:
  - Dynamic ambient header glow matching morning, afternoon, evening, and night moods.
- **Deep OLED Dark Theme**:
  - High-contrast true-black OLED canvas (`#000000`), elevated card surfaces (`#141414`), and vibrant Liner Red accent (`#FF3B3B`).
- **Full Playback & Audio Controls**:
  - Seamless audio streaming powered by `just_audio`.
  - **Pitch Shift & Tempo Controls**: Adjust playback speed (0.5x–2.0x) and musical pitch (0.5x–1.5x) like Liner Desktop.
  - Shuffle, Repeat (Off, All, One), Queue management, and Like track support.
- **Persistent Mini Player**:
  - Docked floating bar above the navigation bar with track info, play/pause, like, and 2px linear scrubber.
  - Smooth hero-style slide transition to Fullscreen Player.
- **Dual-Endpoint API Failover**:
  - Automatically probes the primary Cloudflare API (`https://api.tryliner.fun`) with fallback to Polish Edge Relay (`http://edge.tryliner.fun:10518`).
  - Built-in graceful offline demo catalog so the app is always functional.

---

## 📱 Architecture & Folder Structure

```
liner-mobile/
├── lib/
│   ├── main.dart                       # App entry point, Riverpod ProviderScope, Dark UI overlay
│   ├── core/
│   │   ├── api/
│   │   │   └── api_client.dart         # Dual-endpoint Dio client with health probe & fallbacks
│   │   ├── models/
│   │   │   ├── track.dart              # Track, Playlist, Artist, LyricLine, LyricWord models
│   │   │   └── player_state.dart       # PlaybackStatus, LinerRepeatMode, PlayerStateData
│   │   ├── theme/
│   │   │   └── app_theme.dart          # Liner OLED Dark & Light tokens and typography
│   │   └── utils/
│   │       └── lyric_parser.dart       # Richsync syllable JSON, LRC, and MXM subtitle parser
│   ├── services/
│   │   └── audio_player_service.dart   # just_audio playback manager, queue, streams, pitch/speed
│   ├── providers/
│   │   ├── player_provider.dart        # Riverpod StateNotifier for player state & controls
│   │   └── music_provider.dart         # Providers for popular tracks, daily mixes, search & settings
│   └── ui/
│       ├── navigation/
│       │   └── main_navigation_shell.dart # Mobile bottom navigation (Home, Search, Library, Settings) + MiniPlayer
│       ├── screens/
│       │   ├── home/
│       │   │   └── home_screen.dart     # Ambient time glow, Jump Back In, Daily Mixes, Trending Now
│       │   ├── search/
│       │   │   └── search_screen.dart   # Instant search across tracks & categories
│       │   ├── library/
│       │   │   └── library_screen.dart  # Filter tabs, Liked Songs banner, playlists & artists
│       │   ├── player/
│       │   │   ├── fullscreen_player.dart  # Fullscreen player with mesh background & controls
│       │   │   └── lyrics_view.dart        # Syllable-synced karaoke text view
│       │   └── settings/
│       │       └── settings_screen.dart # API endpoint switch, audio quality, cache clear
│       └── widgets/
│           ├── mini_player.dart         # Docked bottom mini player
│           ├── song_card.dart           # Grid / horizontal carousel cards
│           ├── song_tile.dart           # Ranked track tile with like button
│           └── dynamic_mesh_background.dart # Animated ambient visualizer mesh
└── test/
    └── widget_test.dart                 # LyricParser and active line sync tests
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (>= 3.0.0)
- Android Studio / Xcode / VS Code with Flutter extension
- Connected physical device or emulator

### Installation & Run

```bash
# 1. Navigate to directory
cd D:\Kodingan\liner-mobile

# 2. Get dependencies
flutter pub get

# 3. Run unit tests
flutter test

# 4. Launch app on device / emulator
flutter run
```

---

## 🤝 Contribution to Liner

This mobile app is designed to accompany the official desktop app at [tryliner/desktop](https://github.com/tryliner/desktop). All endpoints, data models, and theme tokens are designed 1:1 with the desktop client.
