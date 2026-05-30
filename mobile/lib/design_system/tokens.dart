// B1 — Design tokens: spacing, radius, shadows, durations.
// Import this file in every component that needs layout constants.

import 'package:flutter/material.dart';

// ─── Spacing ────────────────────────────────────────────────────────────────

abstract class VenaSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

// ─── Border radius ──────────────────────────────────────────────────────────

abstract class VenaRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20; // primary card/button corner
  static const double full = 999;
}

// ─── Shadows ────────────────────────────────────────────────────────────────

abstract class VenaShadows {
  /// Subtle shadow for cards at rest.
  static List<BoxShadow> get card => [
        BoxShadow(
          color: const Color(0xFF5F6C37).withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: const Color(0xFF000000).withValues(alpha: 0.04),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];

  /// More prominent shadow for elevated/floating elements.
  static List<BoxShadow> get elevated => [
        BoxShadow(
          color: const Color(0xFF5F6C37).withValues(alpha: 0.14),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
}

// ─── Animation durations ────────────────────────────────────────────────────

abstract class VenaDuration {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration pulse = Duration(milliseconds: 1500);
}
