import 'package:flutter/material.dart';

/// Design tokens from AGENTS.md section 14.
abstract final class AppColors {
  static const background = Color(0xFFF4F6FB);
  static const card = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFE1E5F0);
  static const text = Color(0xFF14182B);
  static const mutedText = Color(0xFF5B6280);
  static const accent = Color(0xFF3B4BDB);

  static const deadlineText = Color(0xFF9A5B00);
  static const deadlineBg = Color(0xFFFFF1D6);

  static const draftText = Color(0xFF444B66);
  static const draftBg = Color(0xFFECEEF5);
  static const inProgressText = Color(0xFF2D3AB5);
  static const inProgressBg = Color(0xFFE8EAFD);
  static const finalText = Color(0xFF0B6B5F);
  static const finalBg = Color(0xFFDDF5F0);
  static const submittedText = Color(0xFF2F6B16);
  static const submittedBg = Color(0xFFE4F4DC);

  static const subjectBadges = <Color>[
    Color(0xFF3B4BDB),
    Color(0xFF0B7A6B),
    Color(0xFFB4530A),
    Color(0xFF7A3FB5),
  ];
}

abstract final class AppTheme {
  static const double screenPadding = 20;
  static const double cardRadius = 14;
  static const double buttonRadius = 12;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      primary: AppColors.accent,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: Colors.transparent,
      ),
    );
  }
}
