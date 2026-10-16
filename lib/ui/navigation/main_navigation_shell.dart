import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/models/playlist_import.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/deep_link.dart';
import '../../providers/api_provider.dart';
import '../../providers/deep_link_provider.dart';
import '../../providers/import_provider.dart';
import '../../providers/player_provider.dart';
import '../screens/home/home_screen.dart';
import '../screens/library/import_review_screen.dart';
import '../screens/library/library_screen.dart';
import '../screens/player/fullscreen_player.dart';
import '../screens/search/search_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../utils/ui_helpers.dart';
import '../widgets/mini_player.dart';
import 'navigation_helpers.dart';

class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() =>
      _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  static const _screens = <Widget>[
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
    SettingsScreen(),
  ];

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPendingLink());
  }

  void _openPendingLink() {
    if (!mounted) return;
    final target = ref.read(pendingDeepLinkProvider);
    if (target == null) return;
    ref.read(pendingDeepLinkProvider.notifier).consume();
    unawaited(_openLink(target));
  }

  Future<void> _openLink(DeepLinkTarget target) async {
    final navigator = Navigator.of(context);
    switch (target.type) {
      case DeepLinkType.artist:
        await openArtist(navigator, target.id);
      case DeepLinkType.album:
        await openAlbum(navigator, target.id);
      case DeepLinkType.playlist:
        await (DeepLinks.isUserPlaylistId(target.id)
            ? openUserPlaylist(navigator, target.id)
            : openCatalogPlaylist(navigator, target.id));
      case DeepLinkType.track:
        try {
          final track = await ref.read(linerApiProvider).getTrack(target.id);
          if (!mounted) return;
          unawaited(ref.read(playerStateProvider.notifier).playTrack(track));
          await navigator.push(fullscreenPlayerRoute());
        } on ApiException {
          if (mounted) showMessage(context, "Couldn't open that song.");
        }
    }
  }

  void _onImportStatus(ImportStatus? previous, ImportStatus? next) {
    if (next == previous) return;
    switch (next) {
      case ImportStatus.awaitingDecision:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ImportReviewScreen()),
        );
      case ImportStatus.completed:
        showMessage(context, 'Playlist imported');
      case ImportStatus.failed:
        showMessage(context, 'The playlist import failed');
      case null ||
          ImportStatus.queued ||
          ImportStatus.running ||
          ImportStatus.finalizing:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen<ImportStatus?>(
        importControllerProvider.select((state) => state.job?.status),
        _onImportStatus,
      )
      ..listen<DeepLinkTarget?>(
        pendingDeepLinkProvider,
        (_, target) => _openPendingLink(),
      );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: _screens),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MiniPlayer(),
                Container(
                  decoration: BoxDecoration(
                    color: LinerColors.darkSurface.withValues(alpha: 0.96),
                    border: const Border(
                      top: BorderSide(
                        color: LinerColors.darkBorderPrimary,
                        width: 0.8,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: BottomNavigationBar(
                      currentIndex: _currentIndex,
                      onTap: (index) => setState(() => _currentIndex = index),
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      type: BottomNavigationBarType.fixed,
                      selectedItemColor: LinerColors.accentPrimary,
                      unselectedItemColor: Colors.white.withValues(alpha: 0.4),
                      selectedFontSize: 11,
                      unselectedFontSize: 11,
                      selectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                      items: const [
                        BottomNavigationBarItem(
                          icon: Icon(Icons.home_filled),
                          label: 'Home',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.search_rounded),
                          label: 'Search',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.library_music_rounded),
                          label: 'Library',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.tune_rounded),
                          label: 'Settings',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
