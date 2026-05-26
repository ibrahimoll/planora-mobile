import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PlanoraTheme {
  PlanoraTheme._();

  // Brand
  static const Color primaryPurple = Color(0xFF6D4CFF);
  static const Color deepIndigo = Color(0xFF4B2DCC);
  static const Color softViolet = Color(0xFFA78BFA);
  static const Color lavenderGlow = Color(0xFFE9E2FF);

  // Neutrals
  static const Color background = Color(0xFFF6F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF0F2F5);

  // Semantic
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Extra project colors
  static const Color blue = Color(0xFF3B82F6);
  static const Color green = Color(0xFF22C55E);
  static const Color orange = Color(0xFFF97316);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryPurple, deepIndigo],
  );

  static const LinearGradient softGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF2ECFF), Color(0xFFFFFFFF)],
  );

  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x146D4CFF), blurRadius: 30, offset: Offset(0, 10)),
  ];

  static const List<BoxShadow> floatingShadow = [
    BoxShadow(color: Color(0x14000000), blurRadius: 40, offset: Offset(0, 20)),
  ];

  static BorderRadius radiusSmall = BorderRadius.circular(14);
  static BorderRadius radiusMedium = BorderRadius.circular(18);
  static BorderRadius radiusLarge = BorderRadius.circular(24);
  static BorderRadius radiusButton = BorderRadius.circular(16);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: background,
    primaryColor: primaryPurple,

    colorScheme: const ColorScheme.light(
      primary: primaryPurple,
      secondary: softViolet,
      surface: surface,
      error: error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textPrimary,
      onError: Colors.white,
    ),

    textTheme: GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        height: 1.1,
      ),
      headlineLarge: GoogleFonts.plusJakartaSans(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textSecondary,
        height: 1.5,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: textPrimary),
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
    ),

    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shadowColor: primaryPurple.withValues(alpha: 0.08),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      margin: EdgeInsets.zero,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textPrimary,
        minimumSize: const Size(double.infinity, 56),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: GoogleFonts.inter(color: textSecondary, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryPurple, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: error),
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: primaryPurple,
      unselectedItemColor: textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: divider,
      thickness: 1,
      space: 1,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: primaryPurple,
      linearTrackColor: Color(0xFFEDEEF3),
      circularTrackColor: Color(0xFFEDEEF3),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: lavenderGlow,
      selectedColor: primaryPurple,
      disabledColor: border,
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: primaryPurple,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide.none,
      ),
    ),

    iconTheme: const IconThemeData(color: textPrimary, size: 24),
  );
}
