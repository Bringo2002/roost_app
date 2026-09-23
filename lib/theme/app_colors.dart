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

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFF44336);

  /// Online-presence dot (avatar indicator).
  static const Color onlineAccent = Colors.white;

  // ─── Gradient Presets ────────────────────────────────────────────────

  /// Subtle surface gradient for premium card backgrounds.
  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A1A1A), Color(0xFF121212)],
  );

  /// High-contrast gradient for CTA buttons and emphasis elements.
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [white, Color(0xFFE0E0E0)],
  );

  /// Bottom-to-top scrim gradient for image overlays.
  static const LinearGradient imageScrimGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00000000), Color(0x99000000)],
    stops: [0.4, 1.0],
  );

  // ─── Shadow Presets ─────────────────────────────────────────────────

  /// Subtle shadow for flat elements needing minimal depth.
  static final List<BoxShadow> shadowSm = [
    BoxShadow(
      color: black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  /// Medium shadow for cards and elevated containers.
  static final List<BoxShadow> shadowMd = [
    BoxShadow(
      color: black.withValues(alpha: 0.06),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  /// Large shadow for modals, bottom sheets, and overlays.
  static final List<BoxShadow> shadowLg = [
    BoxShadow(
      color: black.withValues(alpha: 0.12),
      blurRadius: 40,
      offset: const Offset(0, 16),
    ),
  ];

  // ─── Animation Duration Tokens ──────────────────────────────────────

  /// Quick micro-interactions: button presses, icon toggles.
  static const Duration durationFast = Duration(milliseconds: 150);

  /// Standard transitions: card reveals, filter changes.
  static const Duration durationMedium = Duration(milliseconds: 300);

  /// Deliberate animations: page transitions, gauge fills.
  static const Duration durationSlow = Duration(milliseconds: 500);

  /// Extended animations: chart draws, trust score count-up.
  static const Duration durationGauge = Duration(milliseconds: 900);

  // ─── Spacing Scale (extends AppSpacing for color-coupled layouts) ───

  /// Standard stagger delay between sequential list item animations.
  static const Duration staggerDelay = Duration(milliseconds: 50);
}
