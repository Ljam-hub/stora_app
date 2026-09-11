import 'package:flutter/material.dart';

/// Extra palette and styling tokens used across the application.
class HomeColors {
  static const navBackground = Color(0xFF130E1B);
  static const cardBackground = Color(0xFF1B1526);
  static const cardElevated = Color(0xFF241D32);
  static const surfaceHover = Color(0xFF2D243E);
  static const cardBorder = Color(0xFF352B46);
  static const cardBorderLight = Color(0xFF4C3E63);
  
  static const successText = Color(0xFF34D399);
  static const successBg = Color(0xFF0E3824);
  
  static const warningText = Color(0xFFFBBF24);
  static const warningBg = Color(0xFF332408);
  
  static const dangerBg = Color(0xFF3A1620);
  static const dangerText = Color(0xFFEF4444);

  static const infoText = Color(0xFF38BDF8);
  static const infoBg = Color(0xFF102A3D);

  static const purpleGradient = LinearGradient(
    colors: [Color(0xFFF56A10), Color(0xFFC2410C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const heroGradient = LinearGradient(
    colors: [Color(0xFFF56A10), Color(0xFFC2410C), Color(0xFF261812)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const meshGradient = LinearGradient(
    colors: [Color(0xFF3D2115), Color(0xFF261812), Color(0xFF160F0C)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const cardShadow = [
    BoxShadow(
      color: Color(0x40000000),
      blurRadius: 16,
      offset: Offset(0, 6),
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
