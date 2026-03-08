// core/app_theme.dart — HiVE App Theme (Bold Yellow + Black)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // 🐝 HiVE Brand Colors
  static const primary       = Color(0xFFFFD600); // Bold bee yellow
  static const primaryDark   = Color(0xFFFFC200); // Slightly deeper yellow for buttons
  static const scaffoldBg    = Color(0xFF0A0A0A); // Deep OLED black
  static const cardBg        = Color(0xFF111111); // Slightly lifted card background
  static const surfaceBg     = Color(0xFF1A1A1A); // Input fields / tiles
  static const dividerColor  = Color(0xFF222222);
  static const textPrimary   = Colors.white;
  static const textSecondary = Color(0xFF999999);

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: scaffoldBg,
    primaryColor: primary,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: primaryDark,
      surface: cardBg,
    ),

    textTheme: GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.dark().textTheme,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: scaffoldBg,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: Colors.white),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.black,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        elevation: 0,
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceBg,
      hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: scaffoldBg,
      selectedItemColor: primary,
      unselectedItemColor: Color(0xFF555555),
      showSelectedLabels: false,
      showUnselectedLabels: false,
      type: BottomNavigationBarType.fixed,
    ),

    dividerColor: dividerColor,
  );
}