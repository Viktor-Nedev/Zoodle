import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static final ThemeData greenTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFFAFAFA),
    primaryColor: const Color(0xFF0B8457),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF0B8457),
      primary: const Color(0xFF0B8457),
      secondary: const Color(0xFF7FC8A9),
      surface: Colors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF0B8457),
      elevation: 0,
      centerTitle: true,
      scrolledUnderElevation: 0,
      titleTextStyle: GoogleFonts.changaOne(
        color: const Color(0xFF0B8457),
        fontSize: 22,
        fontWeight: FontWeight.normal, // Changa One usually doesn't need bold
        letterSpacing: 0.5,
      ),
      iconTheme: const IconThemeData(color: Color(0xFF0B8457)),
      shape: const Border(
        bottom: BorderSide(
          color: Color(0xFF0B8457),
          width: 3.0,
        ),
      ),
    ),
    textTheme: GoogleFonts.outfitTextTheme().apply(
      bodyColor: const Color(0xFF1F2937),
      displayColor: const Color(0xFF111827),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFEFFAF2),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: GoogleFonts.outfit(color: Colors.grey[500]),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0B8457),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF0B8457),
        textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
      ),
    ),

  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF121212),
    primaryColor: const Color(0xFF0B8457),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF0B8457),
      brightness: Brightness.dark,
      primary: const Color(0xFF0B8457),
      secondary: const Color(0xFF7FC8A9),
      surface: const Color(0xFF1E1E1E),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF1E1E1E),
      foregroundColor: const Color(0xFF7FC8A9),
      elevation: 0,
      centerTitle: true,
      scrolledUnderElevation: 0,
      titleTextStyle: GoogleFonts.changaOne(
        color: const Color(0xFF7FC8A9),
        fontSize: 22,
        fontWeight: FontWeight.normal,
        letterSpacing: 0.5,
      ),
      iconTheme: const IconThemeData(color: Color(0xFF7FC8A9)),
      shape: const Border(
        bottom: BorderSide(
          color: Color(0xFF0B8457),
          width: 3.0,
        ),
      ),
    ),
    textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: const Color(0xFFE0E0E0),
      displayColor: const Color(0xFFF5F5F5),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2C2C2C),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: GoogleFonts.outfit(color: Colors.grey[400]),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0B8457),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF7FC8A9),
        textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
      ),
    ),
  );
}
