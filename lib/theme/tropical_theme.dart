import 'package:flutter/material.dart';

class TropicalTheme {
  // Apple HIG-compliant premium palettes with Tropical Green
  static const Color forestGreen = Color(0xFF00B248);     // Brazilian Flag Green (Illuminated)
  static const Color softLeafGreen = Color(0xFF009B3A);   // Brazilian Flag Green (Base)
  static const Color warmTerracotta = Color(0xFFFF453A);  // Apple Red (Destructive/Alert)
  static const Color goldenSand = Color(0xFF8E8E93);      // Apple Gray (Neutral)
  static const Color darkJungle = Color(0xFF000000);      // Pure iOS True Black
  static const Color lightSage = Color(0xFFF2F2F7);       // iOS Light Gray Background
  static const Color deepCharcoal = Color(0xFF1C1C1E);    // iOS Dark Gray Card (System Gray 6)
  static const Color softClay = Color(0xFF3A3A3C);        // iOS Dark Gray Border (System Gray 4)

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: softLeafGreen, // Tropical Light Green
        onPrimary: Colors.white,
        secondary: Color(0xFF007AFF), // iOS Light Blue
        onSecondary: Colors.white,
        error: Color(0xFFFF3B30), // iOS Light Red
        onError: Colors.white,
        surface: Colors.white,
        onSurface: Color(0xFF1C1C1E),
        primaryContainer: Color(0xFFE8F8ED),
        onPrimaryContainer: softLeafGreen,
        secondaryContainer: Color(0xFFE5F2FF),
        onSecondaryContainer: Color(0xFF007AFF),
        surfaceContainerHighest: Color(0xFFF2F2F7),
      ),
      scaffoldBackgroundColor: const Color(0xFFF2F2F7),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.black.withOpacity(0.08), width: 1.0),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: Color(0xFF1C1C1E),
          letterSpacing: -0.8,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1C1C1E),
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1C1C1E),
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: Color(0xFF1C1C1E),
          height: 1.35,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: Color(0xFF3A3A3C),
        ),
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: forestGreen, // Tropical Dark Green
        onPrimary: Colors.black,
        secondary: Color(0xFF0A84FF), // iOS Dark Blue
        onSecondary: Colors.white,
        error: warmTerracotta, // iOS Dark Red
        onError: Colors.white,
        surface: Color(0xFF1C1C1E), // System Gray 6
        onSurface: Color(0xFFECEFF1), // Off-white text!
        primaryContainer: Color(0xFF0E3D1C),
        onPrimaryContainer: forestGreen,
        secondaryContainer: Color(0xFF002A54),
        onSecondaryContainer: Color(0xFF0A84FF),
        surfaceContainerHighest: Color(0xFF2C2C2E),
      ),
      scaffoldBackgroundColor: darkJungle, // True Black background
      cardTheme: CardThemeData(
        color: const Color(0xFF1C1C1E),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.08), width: 1.0),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: Color(0xFFFAFAFA), // Off-white
          letterSpacing: -0.8,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Color(0xFFFAFAFA), // Off-white
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFFFAFAFA), // Off-white
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: Color(0xFFECEFF1), // Premium Off-white
          height: 1.35,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: Color(0xFFECEFF1), // Premium Off-white
        ),
      ),
    );
  }
}
