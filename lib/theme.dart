import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color srmBlue = Color(0xFF003366);
const Color srmLightBlue = Color(0xFF005A9E);
const Color srmAccent = Color(0xFFE87722); // An orange accent color

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: srmBlue,
        primary: srmBlue,
        secondary: srmLightBlue,
        tertiary: srmAccent,
        brightness: Brightness.light,
        surface: const Color(0xFFF5F5F5),
        onSurface: const Color(0xFF1A1A1A),
      ),
      textTheme: GoogleFonts.poppinsTextTheme(
        const TextTheme(
          displayLarge: TextStyle(fontWeight: FontWeight.bold),
          displayMedium: TextStyle(fontWeight: FontWeight.bold),
          displaySmall: TextStyle(fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(fontWeight: FontWeight.w600),
          headlineSmall: TextStyle(fontWeight: FontWeight.w600),
          titleLarge: TextStyle(fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(fontSize: 16.0),
        ),
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      appBarTheme: AppBarTheme(
        backgroundColor: srmBlue,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: srmBlue, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}