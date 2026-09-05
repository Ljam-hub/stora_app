import 'package:flutter/material.dart';

/// Extra palette and styling tokens used across the application.
class HomeColors {
  static const navBackground = Color(0xFF18131E);
  static const cardBackground = Color(0xFF1F1A28);
  static const cardElevated = Color(0xFF262032);
  static const surfaceHover = Color(0xFF2E263C);
  static const cardBorder = Color(0xFF332A40);
  static const cardBorderLight = Color(0xFF453955);
  
  static const successText = Color(0xFF4ADE80);
  static const successBg = Color(0xFF132D1B);
  
  static const warningText = Color(0xFFFBBF24);
  static const warningBg = Color(0xFF332408);
  
  static const dangerBg = Color(0xFF3A1620);
  static const dangerText = Color(0xFFFF6B6B);

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
