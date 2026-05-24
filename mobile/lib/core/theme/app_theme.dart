import 'package:flutter/material.dart';

import 'colors.dart';
import 'text_styles.dart';

class VenaTheme {
  VenaTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: VenaColors.primary,
        surface: VenaColors.surface,
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: VenaColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: VenaColors.background,
        foregroundColor: VenaColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: VenaTextStyles.titleMedium,
      ),
      cardTheme: CardThemeData(
        color: VenaColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: VenaColors.primary,
          foregroundColor: VenaColors.onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: VenaTextStyles.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: VenaColors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: VenaColors.primary, width: 2),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: VenaColors.primary,
        brightness: Brightness.dark,
        surface: VenaColors.surfaceDark,
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: VenaColors.backgroundDark,
      appBarTheme: AppBarTheme(
        backgroundColor: VenaColors.surfaceDark,
        foregroundColor: VenaColors.textPrimaryDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: VenaTextStyles.titleMedium.copyWith(
          color: VenaColors.textPrimaryDark,
        ),
      ),
      cardTheme: CardThemeData(
        color: VenaColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2D2D3F)),
        ),
        margin: EdgeInsets.zero,
      ),
    );
  }
}
