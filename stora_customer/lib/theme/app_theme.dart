import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF0E0B14);
  static const navBackground = Color(0xFF18131E);
  static const cardBackground = Color(0xFF1F1A28);
  static const cardElevated = Color(0xFF262032);
  static const surfaceHover = Color(0xFF2E263C);
  static const cardBorder = Color(0xFF332A40);
  static const cardBorderLight = Color(0xFF453955);

  static const primary = Color(0xFF9B87F5);
  static const primaryDark = Color(0xFF7C3AED);
  static const primaryLight = Color(0xFFBCAAF8);

  static const success = Color(0xFF4ADE80);
  static const successBg = Color(0xFF132D1B);

  static const warning = Color(0xFFFBBF24);
  static const warningBg = Color(0xFF332408);

  static const danger = Color(0xFFFF6B6B);
  static const dangerBg = Color(0xFF3A1620);

  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF9CA3AF);
  static const textMuted = Color(0xFF6B7280);

  static const purpleGradient = LinearGradient(
    colors: [Color(0xFF9B87F5), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const heroGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9), Color(0xFF1E1826)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const cardShadow = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static List<BoxShadow> glowShadow(Color color, {double opacity = 0.25}) => [
        BoxShadow(
          color: color.withValues(alpha: opacity),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ];
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        surface: AppColors.cardBackground,
      ),
      useMaterial3: true,
      fontFamily: null,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.navBackground,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
