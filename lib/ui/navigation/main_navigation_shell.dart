import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/mini_player.dart';
import '../screens/home/home_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/library/library_screen.dart';
import '../screens/settings/settings_screen.dart';

class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
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
                      top: BorderSide(color: LinerColors.darkBorderPrimary, width: 0.8),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: BottomNavigationBar(
                      currentIndex: _currentIndex,
                      onTap: (index) {
                        setState(() => _currentIndex = index);
                      },
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      type: BottomNavigationBarType.fixed,
                      selectedItemColor: LinerColors.accentPrimary,
                      unselectedItemColor: Colors.white.withValues(alpha: 0.4),
                      selectedFontSize: 11,
                      unselectedFontSize: 11,
                      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter'),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontFamily: 'Inter'),
                      items: const [
                        BottomNavigationBarItem(
                          icon: Icon(Icons.home_filled),
                          activeIcon: Icon(Icons.home_filled, color: LinerColors.accentPrimary),
                          label: 'Home',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.search_rounded),
                          activeIcon: Icon(Icons.search_rounded, color: LinerColors.accentPrimary),
                          label: 'Search',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.library_music_rounded),
                          activeIcon: Icon(Icons.library_music_rounded, color: LinerColors.accentPrimary),
                          label: 'Library',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.tune_rounded),
                          activeIcon: Icon(Icons.tune_rounded, color: LinerColors.accentPrimary),
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
