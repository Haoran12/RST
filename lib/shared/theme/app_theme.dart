import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData darkTheme() {
    const colorScheme = ColorScheme.dark(
      primary: AppColors.accentPrimary,
      secondary: AppColors.accentSecondary,
      surface: AppColors.surfaceCard,
      error: AppColors.error,
      onPrimary: AppColors.textStrong,
      onSecondary: AppColors.textStrong,
      onSurface: AppColors.textStrong,
      onError: AppColors.textStrong,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: 'Noto Sans SC',
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.textStrong,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textStrong,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textStrong,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          height: 1.5,
          color: AppColors.textSecondary,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          height: 1.4,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textStrong,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
