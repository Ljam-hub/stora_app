import 'package:flutter/material.dart';
import 'theme_mode_controller.dart';

/// Extra palette and styling tokens used across the application.
class HomeColors {
  static bool get _isDark => ThemeModeController.instance.isDarkMode;

  static const primary = Color(0xFFF97316);

  static Color get background => _isDark ? const Color(0xFF141018) : const Color(0xFFF8F9FA);
  static Color get scaffoldBackground => _isDark ? const Color(0xFF141018) : const Color(0xFFF8F9FA);

  static Color get navBackground => _isDark ? const Color(0xFF130E1B) : Colors.white;
  static Color get cardBackground => _isDark ? const Color(0xFF1B1526) : Colors.white;
  static Color get cardElevated => _isDark ? const Color(0xFF241D32) : const Color(0xFFF8FAFC);
  static Color get surfaceHover => _isDark ? const Color(0xFF2D243E) : const Color(0xFFF1F5F9);
  static Color get cardBorder => _isDark ? const Color(0xFF352B46) : const Color(0xFFE2E8F0);
  static Color get cardBorderLight => _isDark ? const Color(0xFF4C3E63) : const Color(0xFFCBD5E1);

  static Color get textPrimary => _isDark ? Colors.white : const Color(0xFF0F172A);
  static Color get textSecondary => _isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
  static Color get textMuted => _isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  /// High-contrast primary accent text/icon color:
  /// Bright peach/orange in dark mode, rich deep retail orange in light mode.
  static Color get accentText => _isDark ? const Color(0xFFFB923C) : const Color(0xFFC2410C);

  /// High-contrast theme-aware palette tokens for charts, badges, and categories
  static Color get chartGreen => _isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D);
  static Color get chartYellow => _isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
  static Color get chartPurple => _isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
  static Color get chartBlue => _isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1);

  static const successText = Color(0xFF10B981);
  static Color get successBg => _isDark ? const Color(0xFF065F46) : const Color(0xFFD1FAE5);

  static Color get warningText => _isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
  static Color get warningBg => _isDark ? const Color(0xFF332408) : const Color(0xFFFEF3C7);

  static Color get dangerBg => _isDark ? const Color(0xFF3A1620) : const Color(0xFFFEE2E2);
  static Color get dangerText => _isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626);

  static Color get infoText => _isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
  static Color get infoBg => _isDark ? const Color(0xFF102A3D) : const Color(0xFFE0F2FE);

  static const purpleGradient = LinearGradient(
    colors: [Color(0xFFF56A10), Color(0xFFC2410C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get heroGradient => _isDark
      ? const LinearGradient(
          colors: [Color(0xFFF56A10), Color(0xFFC2410C), Color(0xFF261812)],
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
            color: Color(0x40000000),
            blurRadius: 16,
            offset: Offset(0, 6),
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
