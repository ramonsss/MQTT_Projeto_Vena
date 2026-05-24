import 'package:flutter/material.dart';

/// Vena brand colour palette.
abstract class VenaColors {
  // Primary – indigo/teal IoT feel
  static const Color primary = Color(0xFF1A6BFF);
  static const Color primaryDark = Color(0xFF0048CC);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Secondary – warm amber for alerts
  static const Color secondary = Color(0xFFFF8C00);
  static const Color onSecondary = Color(0xFFFFFFFF);

  // Surfaces
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1E2E);
  static const Color surfaceVariant = Color(0xFFF3F4F6);
  static const Color surfaceVariantDark = Color(0xFF2A2A3E);

  // Background
  static const Color background = Color(0xFFF8F9FC);
  static const Color backgroundDark = Color(0xFF12121F);

  // Status colours
  static const Color online = Color(0xFF22C55E);
  static const Color offline = Color(0xFF94A3B8);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // Text
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textPrimaryDark = Color(0xFFE2E8F0);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  // Telemetry chart
  static const Color tempLine = Color(0xFFEF4444);
  static const Color humidityLine = Color(0xFF3B82F6);
}
