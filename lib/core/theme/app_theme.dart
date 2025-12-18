import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static TextTheme _buildTextTheme(TextTheme base) {
    return GoogleFonts.outfitTextTheme(base);
  }

  static ThemeData lightTheme() {
    final base = ThemeData.light();
    return base.copyWith(
      textTheme: _buildTextTheme(base.textTheme),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6366F1), // Indigo
        primary: const Color(0xFF4F46E5), // Stronger Indigo
        secondary: const Color(0xFF0EA5E9), // Sky Blue
        surface: const Color(0xFFEEF2FF), // Very soft Indigo tint (Background)
        surfaceContainerHighest: const Color(
          0xFFE0E7FF,
        ), // Slightly darker tint
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(
        0xFFEEF2FF,
      ), // Soft Indigo Background
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide.none, // Removed border for cleaner look
        ),
        color: const Color(0xFFFFFFFF).withOpacity(0.7), // Glass-like off-white
        shadowColor: const Color(0xFF6366F1).withOpacity(0.05),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Color(0xFF1E293B),
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: Color(0xFF1E293B)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFFFFFF).withOpacity(0.6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none, // Cleaner, no border
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
      ),
    );
  }

  static ThemeData darkTheme() {
    final base = ThemeData.dark();
    return base.copyWith(
      textTheme: _buildTextTheme(
        base.textTheme,
      ).apply(bodyColor: const Color(0xFFE2E8F0), displayColor: Colors.white),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6366F1),
        primary: const Color(0xFF818CF8), // Lighter Indigo for Dark Mode
        secondary: const Color(0xFF2DD4BF), // Lighter Teal
        surface: const Color(0xFF1E293B), // Slate 800
        surfaceContainerHighest: const Color(0xFF334155), // Slate 700
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        color: const Color(0xFF1E293B),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF818CF8), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
      ),
    );
  }
}


