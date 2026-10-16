import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../screens/home/home_screen.dart';
import '../screens/library/library_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../widgets/mini_player.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  static const _screens = <Widget>[
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
    SettingsScreen(),
  ];

  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
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
