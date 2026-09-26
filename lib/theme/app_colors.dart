import 'package:flutter/material.dart';

/// Color tokens from the "Electric Midnight" design system
/// generated in Google Stitch for Muzilla.
class AppColors {
  AppColors._();

  // Core brand colors
  static const Color primary = Color(0xFF3D7BFF); // Electric blue
  static const Color primaryPressed = Color(0xFF2C5EDB);
  static const Color secondary = Color(0xFF70D6FF); // Ice cyan
  static const Color tertiary = Color(0xFF9CC2FF); // Pale celestial mist

  // Neutral / surface palette
  static const Color canvasBase = Color(0xFF070B19); // Void background
  static const Color surfaceDeep = Color(0xFF0A1128); // Starlit substrate
  static const Color surfaceElevated = Color(0x73101A3A); // rgba(16,26,58,0.45)
  static const Color surfaceContainer = Color(0xFF1B1F2E);
  static const Color surfaceContainerHigh = Color(0xFF252939);
  static const Color surfaceContainerHighest = Color(0xFF303444);

  // Text colors
  static const Color textMuted = Color(0xFF8E9BB4); // Airy starlight gray
  static const Color textHighContrast = Color(0xFFF4F7FF); // Starlight white

  // Semantic / error
  static const Color error = Color(0xFFFFB4AB);
  static const Color onError = Color(0xFF690005);
  static const Color errorContainer = Color(0xFF93000A);

  // Outline
  static const Color outline = Color(0xFF8C90A0);
  static const Color outlineVariant = Color(0xFF424654);

  // Gradients used across hero cards / active states
  static const LinearGradient scrubberFill = LinearGradient(
    colors: [primary, secondary],
  );

  static const RadialGradient auroraTopRight = RadialGradient(
    center: Alignment.topRight,
    radius: 1.1,
    colors: [Color(0x2E3D7BFF), Colors.transparent],
  );

  static const RadialGradient auroraBottomLeft = RadialGradient(
    center: Alignment.bottomLeft,
    radius: 1.1,
    colors: [Color(0x1F70D6FF), Colors.transparent],
  );

  // Glow shadows
  static List<BoxShadow> activeGlow = [
    BoxShadow(
      color: primary.withValues(alpha: 0.3),
      blurRadius: 32,
      offset: const Offset(0, 8),
      spreadRadius: -4,
    ),
    BoxShadow(
      color: secondary.withValues(alpha: 0.15),
      blurRadius: 16,
      offset: Offset.zero,
    ),
  ];
}
