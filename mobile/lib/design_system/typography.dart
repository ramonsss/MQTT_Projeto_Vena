// B2 — Typography using Fraunces (headlines/metrics) + Inter (body/labels).
//
// Fraunces is an optical-size, variable serif — great for large feature numbers.
// Inter is a clean geometric sans-serif — optimal for UI body copy.
//
// Usage:
//   Text('24.3°C', style: VenaTypography.metricLarge)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/colors.dart';

abstract class VenaTypography {
  // ── Display / metric (Fraunces) ──────────────────────────────────────────

  /// 64 px — live telemetry value on the device detail screen.
  static TextStyle get metricLarge => GoogleFonts.fraunces(
        fontSize: 64,
        fontWeight: FontWeight.w700,
        letterSpacing: -2.0,
        height: 1.0,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: VenaColors.textPrimary,
      );

  /// 40 px — secondary metric value (e.g. setpoint, humidity).
  static TextStyle get metricMedium => GoogleFonts.fraunces(
        fontSize: 40,
        fontWeight: FontWeight.w600,
        letterSpacing: -1.5,
        height: 1.0,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: VenaColors.textPrimary,
      );

  // ── Headlines (Fraunces) ─────────────────────────────────────────────────

  static TextStyle get headlineLarge => GoogleFonts.fraunces(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: VenaColors.textPrimary,
      );

  static TextStyle get headlineMedium => GoogleFonts.fraunces(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: VenaColors.textPrimary,
      );

  static TextStyle get headlineSmall => GoogleFonts.fraunces(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: VenaColors.textPrimary,
      );

  // ── Body (Inter) ─────────────────────────────────────────────────────────

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: VenaColors.textPrimary,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: VenaColors.textPrimary,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: VenaColors.textSecondary,
      );

  // ── Labels (Inter) ───────────────────────────────────────────────────────

  static TextStyle get labelLarge => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: VenaColors.textPrimary,
      );

  static TextStyle get labelMedium => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
        color: VenaColors.textSecondary,
      );

  static TextStyle get labelSmall => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.8,
        color: VenaColors.textSecondary,
      );

  // ── Button (Inter) ───────────────────────────────────────────────────────

  static TextStyle get button => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      );
}
