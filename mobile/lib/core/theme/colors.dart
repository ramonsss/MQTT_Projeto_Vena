import 'package:flutter/material.dart';

/// Vena brand colour palette — olive green + warm cream.
abstract class VenaColors {
  // Primary — olive green
  static const Color primary = Color(0xFF5F6C37);
  static const Color primaryDark = Color(0xFF4A5429);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Secondary — terracotta (alerts, CTAs)
  static const Color secondary = Color(0xFFC4602A);
  static const Color onSecondary = Color(0xFFFFFFFF);

  // Surfaces (light)
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0E6D3);

  // Surfaces (dark)
  static const Color surfaceDark = Color(0xFF1C1F16);
  static const Color surfaceVariantDark = Color(0xFF2A2D20);

  // Background
  static const Color background = Color(0xFFF7EDDD); // warm cream
  static const Color backgroundDark = Color(0xFF14160F);

  // Status
  static const Color online = Color(0xFF4CAF50);
  static const Color offline = Color(0xFF9B8F7F);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // Text (light)
  static const Color textPrimary = Color(0xFF2D2D1F);
  static const Color textSecondary = Color(0xFF7A6F5F);

  // Text (dark)
  static const Color textPrimaryDark = Color(0xFFE8E4D5);
  static const Color textSecondaryDark = Color(0xFF9B8F7F);

  // Telemetry chart lines
  static const Color tempLine = Color(0xFFC4602A);    // terracotta
  static const Color humidityLine = Color(0xFF5F6C37); // olive
}
