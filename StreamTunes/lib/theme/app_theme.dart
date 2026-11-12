import 'package:flutter/material.dart';

/// Tema global y paleta de colores para StreamTunes (RNF-01)
class AppTheme {
  // Paleta principal estilo Spotify Dark
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF181818);
  static const Color surfaceElevated = Color(0xFF282828);

  // Colores de acento
  static const Color primaryGreen = Color(0xFF1DB954);
  static const Color goldAccent = Color(0xFFFFB800); // Para donaciones y apoyo
  static const Color errorRed = Color(0xFFE91429);

  // Textos y grises
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textMuted = Color(0xFF727272);
  static const Color dividerColor = Color(0xFF3E3E3E);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primaryGreen,
      canvasColor: surface,
      dividerColor: dividerColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryGreen,
        secondary: goldAccent,
        surface: surface,
        error: errorRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: background,
        selectedItemColor: primaryGreen,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 12,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.black,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    );
  }
}
