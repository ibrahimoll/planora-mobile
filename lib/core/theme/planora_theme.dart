import 'package:flutter/material.dart';

class PlanoraTheme {
  static const primary = Color(0xFF4F46F5);
  static const primarySoft = Color(0xFF7C73FF);
  static const primaryLight = Color(0xFFEDEBFF);

  static const lightBgTop = Color(0xFFFFFFFF);
  static const lightBgBottom = Color(0xFFF3F6FF);
  static const lightText = Color(0xFF080B3A);
  static const lightMuted = Color(0xFF5F6680);

  static const darkBgTop = Color(0xFF080B20);
  static const darkBgBottom = Color(0xFF111735);
  static const darkText = Color(0xFFF7F7FF);
  static const darkMuted = Color(0xFFB5B9D6);

  static const screenPadding = 28.0;
  static const buttonHeight = 58.0;
  static const buttonRadius = 20.0;

  static ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightBgTop,
    colorScheme: const ColorScheme.light(
      primary: primary,
      secondary: primarySoft,
      surface: lightBgTop,
      onSurface: lightText,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.w800,
        color: lightText,
        letterSpacing: -1.4,
      ),
      bodyLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: lightMuted,
        height: 1.45,
        letterSpacing: 0.4,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: lightMuted,
        letterSpacing: 0.5,
      ),
    ),
  );

  static ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBgTop,
    colorScheme: const ColorScheme.dark(
      primary: primarySoft,
      secondary: primary,
      surface: darkBgBottom,
      onSurface: darkText,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.w800,
        color: darkText,
        letterSpacing: -1.4,
      ),
      bodyLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: darkMuted,
        height: 1.45,
        letterSpacing: 0.4,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: darkMuted,
        letterSpacing: 0.5,
      ),
    ),
  );
}
