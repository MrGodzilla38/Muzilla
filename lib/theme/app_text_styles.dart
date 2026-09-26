import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Typography scale from the "Electric Midnight" design system.
/// - Headings: Sora (geometric, confident)
/// - Body: Inter (light weights, muted tone)
/// - Labels/metadata: Space Grotesk (tracked, tech-forward)
class AppTextStyles {
  AppTextStyles._();

  static TextStyle _sora({
    required double fontSize,
    required FontWeight weight,
    required double height,
    double letterSpacingEm = 0,
    Color color = AppColors.textHighContrast,
  }) {
    return GoogleFonts.sora(
      fontSize: fontSize,
      fontWeight: weight,
      height: height / fontSize,
      letterSpacing: letterSpacingEm * fontSize,
      color: color,
    );
  }

  static TextStyle _inter({
    required double fontSize,
    required FontWeight weight,
    required double height,
    Color color = AppColors.textMuted,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: weight,
      height: height / fontSize,
      color: color,
    );
  }

  static TextStyle _spaceGrotesk({
    required double fontSize,
    required FontWeight weight,
    required double height,
    double letterSpacingEm = 0,
    Color color = AppColors.textHighContrast,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: fontSize,
      fontWeight: weight,
      height: height / fontSize,
      letterSpacing: letterSpacingEm * fontSize,
      color: color,
    );
  }

  // Headline / display (Sora)
  static TextStyle displayMobile = _sora(
    fontSize: 36,
    weight: FontWeight.w700,
    height: 44,
    letterSpacingEm: -0.02,
  );

  static TextStyle headlineLgMobile = _sora(
    fontSize: 28,
    weight: FontWeight.w600,
    height: 36,
    letterSpacingEm: -0.01,
  );

  static TextStyle headlineMd = _sora(
    fontSize: 28,
    weight: FontWeight.w600,
    height: 36,
    letterSpacingEm: -0.01,
  );

  static TextStyle headlineSm = _sora(
    fontSize: 20,
    weight: FontWeight.w600,
    height: 28,
  );

  // Body (Inter)
  static TextStyle bodyLg = _inter(fontSize: 18, weight: FontWeight.w300, height: 28);
  static TextStyle bodyMd = _inter(fontSize: 15, weight: FontWeight.w400, height: 24);
  static TextStyle bodySm = _inter(fontSize: 13, weight: FontWeight.w400, height: 20);

  // Labels / metadata (Space Grotesk)
  static TextStyle labelLg = _spaceGrotesk(
    fontSize: 14,
    weight: FontWeight.w500,
    height: 20,
    letterSpacingEm: 0.04,
  );

  static TextStyle labelMd = _spaceGrotesk(
    fontSize: 12,
    weight: FontWeight.w500,
    height: 16,
    letterSpacingEm: 0.06,
    color: AppColors.textMuted,
  );

  static TextStyle labelSm = _spaceGrotesk(
    fontSize: 10,
    weight: FontWeight.w600,
    height: 14,
    letterSpacingEm: 0.08,
    color: AppColors.textMuted,
  );
}
