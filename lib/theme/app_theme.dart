import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

/// Shared corner-radius tokens.
class AppRadii {
  AppRadii._();

  static const double card = 20;
  static const double button = 16;
  static const double pill = 999;
}

/// Shared spacing tokens (4pt-ish scale).
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

/// Shared soft-shadow tokens — subtle depth, no Material elevation.
class AppShadows {
  AppShadows._();

  static List<BoxShadow> card = [
    BoxShadow(
      color: AppColors.shadow,
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
}

/// App-wide ThemeData, built from AppColors / AppTextStyles.
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: AppTextStyles.appBarTitle,
      ),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.white,
        onPrimary: AppColors.black,
        surface: AppColors.background,
      ),
      useMaterial3: true,
    );
  }
}
