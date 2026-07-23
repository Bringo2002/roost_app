import 'package:flutter/material.dart';

/// Roost's monochrome brand palette. Black, white, and a grey scale only —
/// no accent colors. Every widget should pull colors from here rather than
/// referencing `Colors.xxx` directly.
class AppColors {
  AppColors._();

  // Core brand
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);

  // Surfaces
  static const Color background = black;
  static const Color surface = Color(0xFF121212);
  static const Color surfaceRaised = Color(0xFF1A1A1A);

  // Greys (100 = lightest, 900 = darkest)
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFE0E0E0);
  static const Color grey300 = Color(0xFFBDBDBD);
  static const Color grey400 = Color(0xFF9E9E9E);
  static const Color grey500 = Color(0xFF757575);
  static const Color grey600 = Color(0xFF616161);
  static const Color grey700 = Color(0xFF424242);
  static const Color grey800 = Color(0xFF2C2C2C);
  static const Color grey900 = Color(0xFF1E1E1E);

  // Text
  static const Color textPrimary = white;
  static const Color textSecondary = grey300;
  static const Color textTertiary = grey500;

  // Borders / dividers
  static const Color border = grey700;
  static const Color divider = grey800;

  // Overlays (used sparingly, e.g. favorite button backing, image scrims)
  static Color scrimDark = black.withValues(alpha: 0.45);
  static Color scrimLight = white.withValues(alpha: 0.12);

  // Shadow
  static Color shadow = black.withValues(alpha: 0.06);

  // Accent — pure white monochrome
  static const Color accent = Colors.white;
  static const Color accentMuted = Color(0xFFE0E0E0);

  /// Online-presence dot (avatar indicator).
  static const Color onlineAccent = Colors.white;
}
