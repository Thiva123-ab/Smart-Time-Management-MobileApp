import 'package:flutter/material.dart';

class AppColors {
  // Primary & Accent
  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryDark = Color(0xFF5843E0);
  static const Color primaryLight = Color(0xFFA29BFE);
  static const Color accentCyan = Color(0xFF00CEC9);
  static const Color accentTeal = Color(0xFF81ECEC);
  static const Color accentPink = Color(0xFFFD79A8);

  // Status Colors
  static const Color success = Color(0xFF00B894);
  static const Color warning = Color(0xFFFFA502);
  static const Color danger = Color(0xFFFF5252);
  static const Color info = Color(0xFF0984E3);

  // Dark Theme
  static const Color backgroundDark = Color(0xFF0F111A);
  static const Color surfaceDark = Color(0xFF181B26);
  static const Color surfaceVariantDark = Color(0xFF222636);
  static const Color cardBorderDark = Color(0xFF2E3447);

  // Text
  static const Color textPrimary = Color(0xFFF5F6FA);
  static const Color textSecondary = Color(0xFFA4B0BE);
  static const Color textMuted = Color(0xFF747D8C);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      primaryColor: AppColors.primary,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.accentCyan,
        surface: AppColors.surfaceDark,
        error: AppColors.danger,
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      cardTheme: CardTheme(
        color: AppColors.surfaceDark,
        elevation: 0,
        shape: RoundedCornerShape(18),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        selectedItemColor: AppColors.accentCyan,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  static RoundedRectangleBorder RoundedCornerShape(double radius) {
    return RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
  }
}
