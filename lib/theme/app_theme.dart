import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData greenTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFF06231A),
    primaryColor: const Color(0xFF0B8457),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF0B8457),
      primary: const Color(0xFF0B8457),
      secondary: const Color(0xFF7FC8A9),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0B8457),
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFEFFAF2),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0B8457),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: const Color(0xFF7FC8A9)),
    ),
  );
}
