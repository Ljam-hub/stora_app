import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme_controller.dart';
export 'theme_controller.dart';

class AppColors {
  static bool get _isDark => CustomerThemeController.instance.isDarkMode;

  static Color get background => _isDark ? const Color(0xFF0E0B14) : const Color(0xFFF8F9FA);
  static Color get navBackground => _isDark ? const Color(0xFF18131E) : Colors.white;
  static Color get cardBackground => _isDark ? const Color(0xFF1F1A28) : Colors.white;
  static Color get cardElevated => _isDark ? const Color(0xFF262032) : const Color(0xFFF1F3F5);
  static Color get surfaceHover => _isDark ? const Color(0xFF2E263C) : const Color(0xFFE5E7EB);
  static Color get cardBorder => _isDark ? const Color(0xFF332A40) : const Color(0xFFE5E7EB);
  static Color get cardBorderLight => _isDark ? const Color(0xFF453955) : const Color(0xFFD1D5DB);

  // Retail Warm Orange & Vibrant Emerald Green
  static const primary = Color(0xFFF56A10);
  static const primaryDark = Color(0xFFC2410C);
  static const primaryLight = Color(0xFFFB923C);

  /// High-contrast primary accent text/icon color:
  /// Bright peach/orange in dark mode, rich deep retail orange in light mode.
  static Color get accentText => _isDark ? const Color(0xFFFB923C) : const Color(0xFFC2410C);

  static const secondary = Color(0xFF10B981);
  static const secondaryLight = Color(0xFF34D399);

  static const success = Color(0xFF10B981);
  static Color get successText => _isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
  static Color get successBg => _isDark ? const Color(0xFF059669) : const Color(0xFFD1FAE5);

  static const warning = Color(0xFFF59E0B);
  static Color get warningText => _isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
  static Color get warningBg => _isDark ? const Color(0xFF332408) : const Color(0xFFFEF3C7);

  static const danger = Color(0xFFEF4444);
  static Color get dangerBg => _isDark ? const Color(0xFF3A1620) : const Color(0xFFFEE2E2);

  static Color get textPrimary => _isDark ? Colors.white : const Color(0xFF111827);
  static Color get textSecondary => _isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
  static Color get textMuted => _isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  static const purpleGradient = LinearGradient(
    colors: [Color(0xFFF56A10), Color(0xFFC2410C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get heroGradient => _isDark
      ? const LinearGradient(
          colors: [Color(0xFFF56A10), Color(0xFFC2410C), Color(0xFF1E1826)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
      : const LinearGradient(
          colors: [Color(0xFFF56A10), Color(0xFFEA580C), Color(0xFFC2410C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

  static LinearGradient get meshGradient => _isDark
      ? const LinearGradient(
          colors: [Color(0xFF3D2115), Color(0xFF261812), Color(0xFF160F0C)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        )
      : const LinearGradient(
          colors: [Color(0xFFFFF7ED), Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );

  static List<BoxShadow> get cardShadow => _isDark
      ? const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ];

  static List<BoxShadow> glowShadow(Color color, {double opacity = 0.25}) => [
        BoxShadow(
          color: color.withValues(alpha: opacity),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0E0B14),
      primaryColor: AppColors.primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        surface: const Color(0xFF1F1A28),
      ),
      useMaterial3: true,
      fontFamily: GoogleFonts.inter().fontFamily,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0E0B14),
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
        backgroundColor: Color(0xFF18131E),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Color(0xFF94A3B8),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1F1A28),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF332A40), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF262032),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF332A40)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF332A40)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      primaryColor: AppColors.primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        surface: Colors.white,
      ),
      useMaterial3: true,
      fontFamily: GoogleFonts.inter().fontFamily,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Color(0xFF1E1E2D),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: Color(0xFF1E1E2D)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Color(0xFF64748B),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.06), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F3F5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
