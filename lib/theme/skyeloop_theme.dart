import 'package:flutter/material.dart';

abstract final class SkyeColors {
  static const ink = Color(0xFF33210E);
  static const blue = Color(0xFF09549B);
  static const amber = Color(0xFFFFB514);
  static const cream = Color(0xFFF8EFE5);
  static const paper = Color(0xFFFFFCF8);
  static const mist = Color(0xFFE8F2F8);
  static const rose = Color(0xFFF4C9C1);
}

ThemeData buildSkyeLoopTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: SkyeColors.blue,
    brightness: Brightness.light,
    primary: SkyeColors.blue,
    secondary: SkyeColors.amber,
    surface: SkyeColors.paper,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: SkyeColors.cream,
    fontFamily: 'sans-serif',
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: SkyeColors.ink,
        fontWeight: FontWeight.w800,
        letterSpacing: -2,
      ),
      headlineMedium: TextStyle(
        color: SkyeColors.ink,
        fontWeight: FontWeight.w800,
      ),
      bodyLarge: TextStyle(color: SkyeColors.ink, height: 1.4),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(180, 58),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: SkyeColors.paper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
  );
}

