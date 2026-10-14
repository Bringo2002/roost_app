import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/widgets/property_detail/roost_bottom_sheet.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Risk flag enum
// ──────────────────────────────────────────────────────────────────────────────

/// Strongly-typed caution flags computed by PropertyRiskService on the backend.
///
/// Each variant carries its own user-facing copy so the widget never needs
/// to map raw strings to UI text at render time.
enum RiskFlag {
  reported(
    title: 'Recently reported',
    detail: 'One or more renters have flagged an issue with this listing. '
        "It hasn't been enough reports to remove it automatically, but "
        'worth reading up before you commit to anything.',
    icon: Icons.flag_outlined,
  ),
  communityInaccurate(
    title: 'Mixed visitor feedback',
    detail: 'Several renters who visited said this listing didn\'t fully '
        'match what was advertised -- photos, location, or price.',
    icon: Icons.groups_outlined,
  ),
  priceBelowMarket(
    title: 'Price well below similar listings',
    detail: 'This price is notably lower than comparable listings nearby. '
        "That's sometimes a genuine deal, but it's also a common pattern "
        'in scam listings -- verify everything before sending any money.',
    icon: Icons.trending_down_rounded,
  );

  const RiskFlag({
    required this.title,
    required this.detail,
    required this.icon,
  });

  final String title;
  final String detail;
  final IconData icon;

  /// Maps a backend JSON string (e.g. `"PRICE_BELOW_MARKET"`) to a typed
  /// [RiskFlag], returning `null` for unrecognised values so the UI
  /// gracefully ignores flags it doesn't know about yet.
  static RiskFlag? fromServer(String raw) => switch (raw) {
        'REPORTED' => RiskFlag.reported,
        'COMMUNITY_INACCURATE' => RiskFlag.communityInaccurate,
        'PRICE_BELOW_MARKET' => RiskFlag.priceBelowMarket,
        _ => null,
      };
}

// ──────────────────────────────────────────────────────────────────────────────
// Constants
// ──────────────────────────────────────────────────────────────────────────────

const _kCardRadius = 16.0;
const _kIconContainerSize = 36.0;

/// Muted amber used for the caution card's tinted background and accents.
/// Intentionally lower opacity so it doesn't fight the monochrome palette.
const _kCautionAmber = AppColors.warning;
const _kCautionAmberTint = AppColors.warningTint; // ~9% opacity
const _kCautionBorder = AppColors.warningBorder; // ~19% opacity

// ──────────────────────────────────────────────────────────────────────────────
// ListingCautionCard
// ──────────────────────────────────────────────────────────────────────────────

/// Shown when a listing has one or more server-computed caution flags
/// (PropertyRiskService on the backend -- report history, negative
/// community-check ratio, or a price well below comparable listings).
///
/// Renders [SizedBox.shrink] when there's nothing to flag, following the
/// same "only speak up when there's something to say" principle
/// [VerificationBadges] uses for GPS/document badges.
class ListingCautionCard extends StatelessWidget {
  const ListingCautionCard({super.key, required this.riskFlags});

  final List<String> riskFlags;

  @override
  Widget build(BuildContext context) {
    final known = riskFlags
        .map(RiskFlag.fromServer)
        .whereType<RiskFlag>()
        .toList(growable: false);

    if (known.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCautionAmberTint,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: _kCautionBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ────────────────────────────────────────────────
          Row(
            children: [
              // Amber-tinted icon container
              Container(
                width: _kIconContainerSize,
                height: _kIconContainerSize,
                decoration: BoxDecoration(
                  color: _kCautionAmber.withAlpha(25),
                  shape: BoxShape.circle,
                  border: Border.all(color: _kCautionAmber.withAlpha(50)),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: _kCautionAmber,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Worth double-checking',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Our system flagged this listing',
                      style: TextStyle(
                        color: AppColors.grey400,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Flag summary chips ────────────────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final flag in known) _FlagChip(flag: flag),
            ],
          ),

          const SizedBox(height: 14),

          // ── Learn more CTA ────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: Material(
              color: AppColors.grey800.withAlpha(180),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showDetails(context, known);
                },
                borderRadius: BorderRadius.circular(10),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.grey300,
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Learn more',
                        style: TextStyle(
                          color: AppColors.grey200,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetails(BuildContext context, List<RiskFlag> known) {
    RoostBottomSheet.show(
      context: context,
      title: 'Worth double-checking',
      subtitle: "Here's what our system flagged about this listing -- none of "
          "these mean it's definitely a problem, just worth a closer look.",
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < known.length; i++) ...[
            _FlagDetailTile(flag: known[i]),
            if (i < known.length - 1) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(color: AppColors.grey800, height: 1),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Flag summary chip (inline card)
// ──────────────────────────────────────────────────────────────────────────────

/// A compact pill that previews a single risk flag inside the card.
class _FlagChip extends StatelessWidget {
  const _FlagChip({required this.flag});

  final RiskFlag flag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.grey700),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(flag.icon, color: _kCautionAmber, size: 13),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              flag.title,
              style: const TextStyle(
                color: AppColors.grey300,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Detail sheet tile
// ──────────────────────────────────────────────────────────────────────────────

/// A single risk-flag row inside the detail bottom sheet. Each flag gets its
/// own icon, title and detail text for clear visual hierarchy.
class _FlagDetailTile extends StatelessWidget {
  const _FlagDetailTile({required this.flag});

  final RiskFlag flag;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Amber-tinted circle with per-flag icon
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: _kCautionAmber.withAlpha(20),
            shape: BoxShape.circle,
            border: Border.all(color: _kCautionAmber.withAlpha(40)),
          ),
          child: Icon(flag.icon, color: _kCautionAmber, size: 15),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                flag.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                flag.detail,
                style: const TextStyle(
                  color: AppColors.grey400,
                  fontSize: 12.5,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
