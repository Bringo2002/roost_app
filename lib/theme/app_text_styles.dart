import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Centralized type scale for Roost. Widgets should reference these instead
/// of constructing inline TextStyles.
///
/// Uses Inter via Google Fonts for a clean, modern feel with optimized
/// letter-spacing and line-height for readability.
class AppTextStyles {
  AppTextStyles._();

  // ─── Base Font Family ───────────────────────────────────────────────

  /// Returns an Inter-based TextStyle. Falls back to system sans-serif.
  static TextStyle _inter({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    double? height,
    double? letterSpacing,
    Color? color,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
      color: color ?? AppColors.textPrimary,
    );
  }

  // ─── Price Styles ───────────────────────────────────────────────────

  /// Large hero price display (detail page, bottom bar).
  static final TextStyle priceDisplay = _inter(
    fontSize: 22,
    fontWeight: FontWeight.w900,
    height: 1.2,
    letterSpacing: -0.5,
  );

  /// Standard price on property cards.
  static final TextStyle price = _inter(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    height: 1.2,
    letterSpacing: -0.3,
  );

  /// Compact price variant for smaller card layouts.
  static final TextStyle priceCompact = _inter(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    height: 1.2,
    letterSpacing: -0.3,
  );

  /// Small inline price (cost breakdown rows, comparisons).
  static final TextStyle priceSmall = _inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  // ─── Heading & Title Styles ─────────────────────────────────────────

  /// Large display text for modals, celebration sheets, hero sections.
  static final TextStyle displayLarge = _inter(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    height: 1.15,
    letterSpacing: -0.5,
  );

  /// Property card / list item title.
  static final TextStyle title = _inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.1,
  );

  /// Section headers on detail pages.
  static final TextStyle sectionHeader = _inter(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: 0.1,
  );

  /// App bar title — brand lockup style.
  static final TextStyle appBarTitle = _inter(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: 2,
  );

  // ─── Body & Description Styles ──────────────────────────────────────

  /// Primary body text.
  static final TextStyle body = _inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.1,
  );

  /// Location labels on cards and detail pages.
  static final TextStyle location = _inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: AppColors.textSecondary,
  );

  /// Tertiary metadata text (dates, counts, dimensions).
  static final TextStyle meta = _inter(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.3,
    color: AppColors.textTertiary,
  );

  // ─── Label & Badge Styles ──────────────────────────────────────────

  /// Filter chips and amenity labels.
  static final TextStyle chipLabel = _inter(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
  );

  /// Small captions and footnotes.
  static final TextStyle caption = _inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: AppColors.textTertiary,
  );

  /// Badge text (verification, status pills).
  static final TextStyle badge = _inter(
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );

  /// Button text — standard.
  static final TextStyle button = _inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.2,
  );

  /// Button text — small.
  static final TextStyle buttonSmall = _inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.2,
  );
}
