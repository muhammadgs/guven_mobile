import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const Color primaryColor = Color(0xFF6D4AFF);
  static const Color backgroundColor = Color(0xFFF8F7FC);
  static const Color textColor = Color(0xFF17151F);

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: backgroundColor,
      // Poppins is the app's text face; CalSans is reserved for display
      // moments and is always asked for by name. Setting it here rather than
      // per-widget catches the text this app does not build itself — the
      // bottom nav bar's labels come out of the package with a size, a weight
      // and a colour but no family, so without this they fall back to Roboto.
      fontFamily: 'Poppins',
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
      ),
    );
  }
}