import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PlanoraTheme {
  PlanoraTheme._();

  // Brand colors from the current Planora mobile design export.
  static const Color primaryPurple = Color(0xFF6D28D9);
  static const Color secondaryPurple = Color(0xFF7C3AED);
  static const Color primaryLight = Color(0x1A6D28D9);
  static const Color secondaryLight = Color(0x1A7C3AED);

  // Light surfaces and text.
  static const Color background = Color(0xFFF8FAFC);
  static const Color secondaryBackground = Color(0xFFF1F5F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF3F4F6);
  static const Color lavenderSurface = Color(0xFFF3EEFF);
  static const Color lavenderBorder = Color(0xFFE6DDFB);
  static const Color lavenderCard = Color(0xFFF7F4FF);
  static const Color textPrimary = Color(0xFF1E1B4B);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF3F4F6);

  // Dark surfaces and text from the mobile design export.
  static const Color darkPrimary = Color(0xFFA78BFA);
  static const Color darkSecondary = Color(0xFFC4B5FD);
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkSurfaceVariant = Color(0xFF273449);
  static const Color darkToggleSurface = Color(0xFF0E1420);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkTextMuted = Color(0xFF94A3B8);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkDivider = Color(0xFF1E293B);
  static const Color darkPrimaryContainer = Color(0x332A1558);

  // Semantic colors.
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  static const Color accent = Color(0xFFF59E0B);

  // Backward-compatible aliases used by older screens.
  static const Color deepIndigo = primaryPurple;
  static const Color softViolet = secondaryPurple;
  static const Color lavenderGlow = primaryLight;
  static const Color blue = info;
  static const Color green = success;
  static const Color orange = Color(0xFFF97316);

  // Radii from the design export.
  static BorderRadius radiusSmall = BorderRadius.circular(8);
  static BorderRadius radiusMedium = BorderRadius.circular(12);
  static BorderRadius radiusLarge = BorderRadius.circular(20);
  static BorderRadius radiusXL = BorderRadius.circular(28);
  static BorderRadius radiusXXL = BorderRadius.circular(40);
  static BorderRadius radiusButton = BorderRadius.circular(20);
  static BorderRadius radiusFull = BorderRadius.circular(9999);

  // Primary button gradient.
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [secondaryPurple, primaryPurple],
  );

  static const LinearGradient darkPrimaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [secondaryPurple, primaryPurple],
  );

  // Light app/onboarding background.
  static const LinearGradient onboardingBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [background, surface],
  );

  static const LinearGradient darkOnboardingBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [darkBackground, Color(0xFF1A1233)],
  );

  // Soft purple card/illustration gradients.
  static const LinearGradient softPurpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF5F3FF), surface],
  );

  static const LinearGradient darkSoftPurpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A1558), darkSurface],
  );

  static const LinearGradient softGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF5F3FF), surface],
  );

  static const LinearGradient darkSoftGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A1558), darkSurface],
  );

  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> darkCardShadow = [
    BoxShadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 5)),
  ];

  static const List<BoxShadow> softCardShadow = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> darkSoftCardShadow = [
    BoxShadow(color: Color(0x80000000), blurRadius: 18, offset: Offset(0, 10)),
  ];

  static const List<BoxShadow> floatingShadow = [
    BoxShadow(color: Color(0x267C3AED), blurRadius: 24, offset: Offset(0, 12)),
  ];

  static const List<BoxShadow> darkFloatingShadow = [
    BoxShadow(color: Color(0x4DA78BFA), blurRadius: 24, offset: Offset(0, 12)),
  ];

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static LinearGradient onboardingBackgroundFor(BuildContext context) =>
      isDark(context) ? darkOnboardingBackground : onboardingBackground;

  static LinearGradient softPurpleGradientFor(BuildContext context) =>
      isDark(context) ? darkSoftPurpleGradient : softPurpleGradient;

  static LinearGradient softGradientFor(BuildContext context) =>
      isDark(context) ? darkSoftGradient : softGradient;

  static LinearGradient primaryGradientFor(BuildContext context) =>
      isDark(context) ? darkPrimaryGradient : primaryGradient;

  static List<BoxShadow> cardShadowFor(BuildContext context) =>
      isDark(context) ? darkCardShadow : cardShadow;

  static List<BoxShadow> softCardShadowFor(BuildContext context) =>
      isDark(context) ? darkSoftCardShadow : softCardShadow;

  static List<BoxShadow> floatingShadowFor(BuildContext context) =>
      isDark(context) ? darkFloatingShadow : floatingShadow;

  static TextTheme get _textTheme => GoogleFonts.interTextTheme().copyWith(
    displayLarge: GoogleFonts.plusJakartaSans(
      fontSize: 56,
      fontWeight: FontWeight.w800,
      color: textPrimary,
      height: 1.1,
      letterSpacing: 0,
    ),
    displayMedium: GoogleFonts.plusJakartaSans(
      fontSize: 44,
      fontWeight: FontWeight.w800,
      color: textPrimary,
      height: 1.15,
      letterSpacing: 0,
    ),
    displaySmall: GoogleFonts.plusJakartaSans(
      fontSize: 36,
      fontWeight: FontWeight.w700,
      color: textPrimary,
      height: 1.2,
      letterSpacing: 0,
    ),
    headlineLarge: GoogleFonts.plusJakartaSans(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: textPrimary,
      height: 1.2,
      letterSpacing: 0,
    ),
    headlineMedium: GoogleFonts.plusJakartaSans(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: textPrimary,
      height: 1.2,
      letterSpacing: 0,
    ),
    headlineSmall: GoogleFonts.plusJakartaSans(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: textPrimary,
      height: 1.3,
      letterSpacing: 0,
    ),
    titleLarge: GoogleFonts.plusJakartaSans(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: textPrimary,
      height: 1.3,
    ),
    titleMedium: GoogleFonts.plusJakartaSans(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: textPrimary,
      height: 1.4,
    ),
    titleSmall: GoogleFonts.plusJakartaSans(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: textPrimary,
      height: 1.4,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: textPrimary,
      height: 1.5,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: textSecondary,
      height: 1.5,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: textSecondary,
      height: 1.4,
    ),
    labelLarge: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Colors.white,
      height: 1.3,
    ),
    labelMedium: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: textPrimary,
      height: 1.3,
    ),
    labelSmall: GoogleFonts.inter(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: textSecondary,
      height: 1.2,
      letterSpacing: 0,
    ),
  );

  static TextTheme get _darkTextTheme =>
      GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 56,
          fontWeight: FontWeight.w800,
          color: darkTextPrimary,
          height: 1.1,
          letterSpacing: 0,
        ),
        displayMedium: GoogleFonts.plusJakartaSans(
          fontSize: 44,
          fontWeight: FontWeight.w800,
          color: darkTextPrimary,
          height: 1.15,
          letterSpacing: 0,
        ),
        displaySmall: GoogleFonts.plusJakartaSans(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: darkTextPrimary,
          height: 1.2,
          letterSpacing: 0,
        ),
        headlineLarge: GoogleFonts.plusJakartaSans(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: darkTextPrimary,
          height: 1.2,
          letterSpacing: 0,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: darkTextPrimary,
          height: 1.2,
          letterSpacing: 0,
        ),
        headlineSmall: GoogleFonts.plusJakartaSans(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
          height: 1.3,
          letterSpacing: 0,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
          height: 1.3,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
          height: 1.4,
        ),
        titleSmall: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
          height: 1.4,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: darkTextPrimary,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: darkTextSecondary,
          height: 1.5,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: darkTextSecondary,
          height: 1.4,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: darkBackground,
          height: 1.3,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
          height: 1.3,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: darkTextSecondary,
          height: 1.2,
          letterSpacing: 0,
        ),
      );

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: background,
    primaryColor: primaryPurple,
    fontFamily: GoogleFonts.inter().fontFamily,

    colorScheme: const ColorScheme.light(
      primary: primaryPurple,
      onPrimary: Colors.white,
      primaryContainer: primaryLight,
      onPrimaryContainer: textPrimary,
      secondary: secondaryPurple,
      onSecondary: Colors.white,
      secondaryContainer: secondaryLight,
      onSecondaryContainer: textPrimary,
      tertiary: accent,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0x1AF59E0B),
      onTertiaryContainer: textPrimary,
      error: error,
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: surfaceVariant,
      onSurfaceVariant: textSecondary,
      outline: border,
      outlineVariant: divider,
    ),

    textTheme: _textTheme,

    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: textPrimary),
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        height: 1.3,
      ),
    ),

    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shadowColor: const Color(0x1A000000),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, 56),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        minimumSize: const Size(double.infinity, 56),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        side: const BorderSide(color: border, width: 1.2),
        textStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryPurple,
        textStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      hintStyle: GoogleFonts.inter(
        color: textMuted,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      labelStyle: GoogleFonts.inter(
        color: textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      floatingLabelStyle: GoogleFonts.inter(
        color: primaryPurple,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.5,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryPurple, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error, width: 1.6),
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
        fontWeight: FontWeight.w400,
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: divider,
      thickness: 1,
      space: 1,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: primaryPurple,
      linearTrackColor: primaryLight,
      circularTrackColor: primaryLight,
    ),

    chipTheme: ChipThemeData(
      backgroundColor: primaryLight,
      selectedColor: primaryPurple,
      disabledColor: surfaceVariant,
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: primaryPurple,
      ),
      secondaryLabelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9999),
        side: BorderSide.none,
      ),
    ),

    iconTheme: const IconThemeData(color: textPrimary, size: 24),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: textPrimary,
      contentTextStyle: GoogleFonts.inter(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBackground,
    primaryColor: darkPrimary,
    fontFamily: GoogleFonts.inter().fontFamily,

    colorScheme: const ColorScheme.dark(
      primary: darkPrimary,
      onPrimary: darkBackground,
      primaryContainer: darkPrimaryContainer,
      onPrimaryContainer: darkTextPrimary,
      secondary: darkSecondary,
      onSecondary: darkBackground,
      secondaryContainer: Color(0x33C4B5FD),
      onSecondaryContainer: darkTextPrimary,
      tertiary: accent,
      onTertiary: darkBackground,
      tertiaryContainer: Color(0x33F59E0B),
      onTertiaryContainer: darkTextPrimary,
      error: error,
      onError: Colors.white,
      surface: darkSurface,
      onSurface: darkTextPrimary,
      surfaceContainerHighest: darkSurfaceVariant,
      onSurfaceVariant: darkTextSecondary,
      outline: darkBorder,
      outlineVariant: darkDivider,
    ),

    textTheme: _darkTextTheme,

    appBarTheme: AppBarTheme(
      backgroundColor: darkBackground,
      foregroundColor: darkTextPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: darkTextPrimary),
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: darkTextPrimary,
        height: 1.3,
      ),
    ),

    cardTheme: CardThemeData(
      color: darkSurface,
      elevation: 0,
      shadowColor: const Color(0x66000000),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: darkPrimary,
        foregroundColor: darkBackground,
        elevation: 0,
        minimumSize: const Size(double.infinity, 56),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        minimumSize: const Size(double.infinity, 56),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        side: const BorderSide(color: darkBorder, width: 1.2),
        textStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: darkSecondary,
        textStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      hintStyle: GoogleFonts.inter(
        color: darkTextMuted,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      labelStyle: GoogleFonts.inter(
        color: darkTextSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      floatingLabelStyle: GoogleFonts.inter(
        color: darkPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.5,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: darkPrimary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error, width: 1.6),
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: darkSurface,
      selectedItemColor: darkPrimary,
      unselectedItemColor: darkTextMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: darkDivider,
      thickness: 1,
      space: 1,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: darkPrimary,
      linearTrackColor: darkPrimaryContainer,
      circularTrackColor: darkPrimaryContainer,
    ),

    chipTheme: ChipThemeData(
      backgroundColor: darkPrimaryContainer,
      selectedColor: darkPrimary,
      disabledColor: darkSurfaceVariant,
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: darkTextPrimary,
      ),
      secondaryLabelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: darkBackground,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9999),
        side: BorderSide.none,
      ),
    ),

    iconTheme: const IconThemeData(color: darkTextPrimary, size: 24),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: darkTextPrimary,
      contentTextStyle: GoogleFonts.inter(
        color: darkBackground,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
