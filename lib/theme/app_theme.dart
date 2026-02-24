import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF0F7A5C),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFCFF5E6),
    onPrimaryContainer: Color(0xFF062E22),
    secondary: Color(0xFF2BAE84),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFD9F7EC),
    onSecondaryContainer: Color(0xFF063426),
    tertiary: Color(0xFF6CCFAE),
    onTertiary: Color(0xFF063A2B),
    tertiaryContainer: Color(0xFFBFF3E0),
    onTertiaryContainer: Color(0xFF043125),
    error: Color(0xFFB42318),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFEE4E2),
    onErrorContainer: Color(0xFF7A271A),
    surface: Color(0xFFF6FBF9),
    onSurface: Color(0xFF102219),
    surfaceVariant: Color(0xFFE1F1EA),
    onSurfaceVariant: Color(0xFF3A4E44),
    outline: Color(0xFFB5CBC0),
    outlineVariant: Color(0xFFD3E2DA),
    shadow: Color(0xFF0B1A14),
    scrim: Color(0xFF0B1A14),
    inverseSurface: Color(0xFF1E2B24),
    onInverseSurface: Color(0xFFF3F7F5),
    inversePrimary: Color(0xFF67D7B2),
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF67D7B2),
    onPrimary: Color(0xFF062E22),
    primaryContainer: Color(0xFF0A4A37),
    onPrimaryContainer: Color(0xFFBFF3E0),
    secondary: Color(0xFF3FC59A),
    onSecondary: Color(0xFF062E22),
    secondaryContainer: Color(0xFF0D3F31),
    onSecondaryContainer: Color(0xFFD9F7EC),
    tertiary: Color(0xFF8BE6C7),
    onTertiary: Color(0xFF053326),
    tertiaryContainer: Color(0xFF135543),
    onTertiaryContainer: Color(0xFFD5F8EB),
    error: Color(0xFFF97066),
    onError: Color(0xFF7A271A),
    errorContainer: Color(0xFF912018),
    onErrorContainer: Color(0xFFFEE4E2),
    surface: Color(0xFF0E1612),
    onSurface: Color(0xFFEAF4EF),
    surfaceVariant: Color(0xFF1A2620),
    onSurfaceVariant: Color(0xFFB6C9BF),
    outline: Color(0xFF42564D),
    outlineVariant: Color(0xFF2A3B34),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFEAF4EF),
    onInverseSurface: Color(0xFF0E1612),
    inversePrimary: Color(0xFF0F7A5C),
  );

  static final ThemeData greenTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: _lightScheme,
    scaffoldBackgroundColor: _lightScheme.surface,
    textTheme: GoogleFonts.spaceGroteskTextTheme().apply(
      bodyColor: _lightScheme.onSurface,
      displayColor: _lightScheme.onSurface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: _lightScheme.surface,
      foregroundColor: _lightScheme.onSurface,
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 0,
      titleTextStyle: GoogleFonts.spaceGrotesk(
        color: _lightScheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
      iconTheme: IconThemeData(color: _lightScheme.onSurface),
    ),
    cardTheme: CardThemeData(
      color: _lightScheme.surface,
      elevation: 2,
      shadowColor: _lightScheme.shadow.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _lightScheme.surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _lightScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _lightScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _lightScheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _lightScheme.primary,
        foregroundColor: _lightScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _lightScheme.primary,
        textStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: _lightScheme.surfaceVariant,
      selectedColor: _lightScheme.primaryContainer,
      labelStyle: GoogleFonts.spaceGrotesk(color: _lightScheme.onSurface),
      secondaryLabelStyle: GoogleFonts.spaceGrotesk(color: _lightScheme.onPrimaryContainer),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: _lightScheme.inverseSurface,
      contentTextStyle: GoogleFonts.spaceGrotesk(color: _lightScheme.onInverseSurface),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: DividerThemeData(
      color: _lightScheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: _lightScheme.primary,
      foregroundColor: _lightScheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: _darkScheme,
    scaffoldBackgroundColor: _darkScheme.surface,
    textTheme: GoogleFonts.spaceGroteskTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: _darkScheme.onSurface,
      displayColor: _darkScheme.onSurface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: _darkScheme.surface,
      foregroundColor: _darkScheme.onSurface,
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 0,
      titleTextStyle: GoogleFonts.spaceGrotesk(
        color: _darkScheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
      iconTheme: IconThemeData(color: _darkScheme.onSurface),
    ),
    cardTheme: CardThemeData(
      color: _darkScheme.surfaceVariant,
      elevation: 1,
      shadowColor: _darkScheme.shadow.withOpacity(0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _darkScheme.surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _darkScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _darkScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _darkScheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _darkScheme.primary,
        foregroundColor: _darkScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _darkScheme.primary,
        textStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: _darkScheme.surfaceVariant,
      selectedColor: _darkScheme.primaryContainer,
      labelStyle: GoogleFonts.spaceGrotesk(color: _darkScheme.onSurface),
      secondaryLabelStyle: GoogleFonts.spaceGrotesk(color: _darkScheme.onPrimaryContainer),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: _darkScheme.inverseSurface,
      contentTextStyle: GoogleFonts.spaceGrotesk(color: _darkScheme.onInverseSurface),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: DividerThemeData(
      color: _darkScheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: _darkScheme.primary,
      foregroundColor: _darkScheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
