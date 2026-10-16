import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// Design tokens mirroring Liner Desktop globals.css
class LinerColors {
  // ── Dark Theme (primary) ──────────────────────────────────────────
  static const darkCanvas   = Color(0xFF000000);
  static const darkSurface  = Color(0xFF0A0A0A);
  static const darkPrimary  = Color(0xFF0A0A0A);
  static const darkElevated = Color(0xFF141414);
  static const darkPanel    = Color(0xFF1A1A1A);

  static const darkTextPrimary   = Color(0xFFFFFFFF);
  static const darkTextSecondary = Color(0xA6FFFFFF); // ~65%
  static const darkTextTertiary  = Color(0x73FFFFFF); // ~45%

  static const darkBorderPrimary   = Color(0xFF1A1A1A);
  static const darkBorderSecondary = Color(0xFF262626);

  // ── Light Theme ───────────────────────────────────────────────────
  static const lightCanvas   = Color(0xFFE4E4E7);
  static const lightSurface  = Color(0xFFFFFFFF);
  static const lightPrimary  = Color(0xFFF5F5F7);
  static const lightElevated = Color(0xFFE6E6EB);
  static const lightPanel    = Color(0xFFDEDEE3);

  static const lightTextPrimary   = Color(0xFF18181B);
  static const lightTextSecondary = Color(0xA618181B); // ~65%
  static const lightTextTertiary  = Color(0x7318181B); // ~45%

  static const lightBorderPrimary   = Color(0xFFE4E4E7);
  static const lightBorderSecondary = Color(0xFFD4D4D8);

  // ── Accent (shared) ───────────────────────────────────────────────
  static const accentPrimary   = Color(0xFFFF3B3B);
  static const accentSecondary = Color(0xFFFF5C5C);
  static const accentTertiary  = Color(0xFFFF7D7D);
  static const accentWarning   = Color(0xFFD97706);
}

class LinerTheme {
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: LinerColors.darkCanvas,
        colorScheme: const ColorScheme.dark(
          surface: LinerColors.darkSurface,
          primary: LinerColors.accentPrimary,
          onPrimary: Colors.white,
          secondary: LinerColors.accentSecondary,
          onSurface: LinerColors.darkTextPrimary,
          outline: LinerColors.darkBorderPrimary,
        ),
        fontFamily: 'Inter',
        textTheme: _buildTextTheme(LinerColors.darkTextPrimary, LinerColors.darkTextSecondary),
        cardTheme: CardThemeData(
          color: LinerColors.darkElevated,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: LinerColors.darkPanel,
          selectedItemColor: LinerColors.accentPrimary,
          unselectedItemColor: LinerColors.darkTextTertiary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: LinerColors.darkPrimary,
          foregroundColor: LinerColors.darkTextPrimary,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: LinerColors.darkTextPrimary,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: LinerColors.darkElevated,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          hintStyle: const TextStyle(color: LinerColors.darkTextTertiary),
        ),
        dividerColor: LinerColors.darkBorderPrimary,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: LinerColors.lightCanvas,
        colorScheme: const ColorScheme.light(
          surface: LinerColors.lightSurface,
          primary: LinerColors.accentPrimary,
          onPrimary: Colors.white,
          secondary: LinerColors.accentSecondary,
          onSurface: LinerColors.lightTextPrimary,
          outline: LinerColors.lightBorderPrimary,
        ),
        fontFamily: 'Inter',
        textTheme: _buildTextTheme(LinerColors.lightTextPrimary, LinerColors.lightTextSecondary),
        cardTheme: CardThemeData(
          color: LinerColors.lightSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: LinerColors.lightPanel,
          selectedItemColor: LinerColors.accentPrimary,
          unselectedItemColor: LinerColors.lightTextTertiary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: LinerColors.lightPrimary,
          foregroundColor: LinerColors.lightTextPrimary,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: LinerColors.lightTextPrimary,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: LinerColors.lightElevated,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          hintStyle: const TextStyle(color: LinerColors.lightTextTertiary),
        ),
        dividerColor: LinerColors.lightBorderSecondary,
      );

  static TextTheme _buildTextTheme(Color primary, Color secondary) => TextTheme(
        displayLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 32, color: primary),
        displayMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 26, color: primary),
        headlineLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 22, color: primary),
        headlineMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 18, color: primary),
        headlineSmall: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 16, color: primary),
        titleLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 15, color: primary),
        titleMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 14, color: primary),
        titleSmall: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 13, color: secondary),
        bodyLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w400, fontSize: 15, color: primary),
        bodyMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w400, fontSize: 14, color: primary),
        bodySmall: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w400, fontSize: 12, color: secondary),
        labelLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 13, color: primary),
        labelSmall: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 11, color: secondary),
      );
}
