// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  static const Color teal = Color(0xFF6CD6CE);
  static const Color orange = Color(0xFFF86E01);
  static const Color darkText = Color(0xFF1A1A1A);
  static const Color lightGray = Color(0xFFF5F5F5);
  static const Color mediumGray = Color(0xFFE0E0E0);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: teal,
      secondary: orange,
      surface: Colors.white,
      error: Colors.red,
    ),
    scaffoldBackgroundColor: Color(0xFFF3F9F5),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF3F9F5),
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: darkText,
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: darkText),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: darkText,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: darkText,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: darkText,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: Color(0xFF666666),
      ),
      labelSmall: TextStyle(
        fontSize: 12,
        color: Color(0xFF999999),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: orange,
      foregroundColor: Colors.white,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: teal,
      secondary: orange,
      surface: Color(0xFF1C1C1C),
      error: Colors.redAccent,
    ),
    scaffoldBackgroundColor: const Color(0xFF212222),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF212222),
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: Colors.white70,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: Colors.white60,
      ),
      labelSmall: TextStyle(
        fontSize: 12,
        color: Colors.white54,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: orange,
      foregroundColor: Colors.white,
    ),
    dividerColor: Colors.white10,
    cardColor: const Color(0xFF1E1E1E), dialogTheme: DialogThemeData(backgroundColor: const Color(0xFF1E1E1E)),
  );
}
