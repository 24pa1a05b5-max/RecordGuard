import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand & Clinical Palette
  static const Color primaryNavy = Color(0xFF0A192F);
  static const Color secondaryNavy = Color(0xFF1E293B);
  static const Color accentTeal = Color(0xFF0D9488);
  static const Color tealLight = Color(0xFFCCFBF1);
  static const Color accentBlue = Color(0xFF0284C7);
  static const Color bgNeutral = Color(0xFFF8FAFC);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color borderSubtle = Color(0xFFE2E8F0);

  // Status Colors
  static const Color dangerRose = Color(0xFFE11D48);
  static const Color dangerLight = Color(0xFFFFE4E6);
  static const Color warningAmber = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color successGreen = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color infoBlue = Color(0xFF2563EB);
  static const Color infoLight = Color(0xFFDBEAFE);

  static ThemeData get lightTheme {
    final baseFont = GoogleFonts.interTextTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgNeutral,
      colorScheme: const ColorScheme.light(
        primary: accentTeal,
        onPrimary: Colors.white,
        primaryContainer: tealLight,
        onPrimaryContainer: Color(0xFF115E59),
        secondary: accentBlue,
        onSecondary: Colors.white,
        surface: surfaceCard,
        onSurface: primaryNavy,
        error: dangerRose,
        onError: Colors.white,
      ),
      textTheme: baseFont.copyWith(
        headlineLarge: baseFont.headlineLarge?.copyWith(
          color: primaryNavy,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: baseFont.headlineMedium?.copyWith(
          color: primaryNavy,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        titleLarge: baseFont.titleLarge?.copyWith(
          color: primaryNavy,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: baseFont.titleMedium?.copyWith(
          color: primaryNavy,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: baseFont.bodyLarge?.copyWith(color: secondaryNavy),
        bodyMedium: baseFont.bodyMedium?.copyWith(color: secondaryNavy),
        bodySmall: baseFont.bodySmall?.copyWith(color: const Color(0xFF64748B)),
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderSubtle,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceCard,
        foregroundColor: primaryNavy,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        shape: Border(bottom: BorderSide(color: borderSubtle, width: 1)),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: surfaceCard,
        selectedIconTheme: IconThemeData(color: accentTeal),
        unselectedIconTheme: IconThemeData(color: Color(0xFF64748B)),
        selectedLabelTextStyle: TextStyle(
          color: accentTeal,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: Color(0xFF64748B),
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentTeal,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryNavy,
          side: const BorderSide(color: borderSubtle, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: accentTeal, width: 1.5),
        ),
      ),
    );
  }
}
