import 'package:flutter/material.dart';
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
  ),
  communityInaccurate(
    title: 'Mixed visitor feedback',
    detail: 'Several renters who visited said this listing didn\'t fully '
        'match what was advertised -- photos, location, or price.',
  ),
  priceBelowMarket(
    title: 'Price well below similar listings',
    detail: 'This price is notably lower than comparable listings nearby. '
        "That's sometimes a genuine deal, but it's also a common pattern "
        'in scam listings -- verify everything before sending any money.',
  );

  const RiskFlag({required this.title, required this.detail});

  final String title;
  final String detail;

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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey700, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, color: AppColors.white, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Worth double-checking',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            known.map((f) => f.title).join(' · '),
            style: const TextStyle(
              color: AppColors.grey300,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showDetails(context, known),
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Text(
                  'Learn more',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
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
            if (i < known.length - 1) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Extracted leaf widget
// ──────────────────────────────────────────────────────────────────────────────

/// A single risk-flag row inside the detail bottom sheet. Extracted so each
/// flag renders as a focused, reusable widget rather than inline build logic.
class _FlagDetailTile extends StatelessWidget {
  const _FlagDetailTile({required this.flag});

  final RiskFlag flag;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.error_outline, color: AppColors.white, size: 16),
        ),
        const SizedBox(width: 10),
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
              const SizedBox(height: 3),
              Text(
                flag.detail,
                style: const TextStyle(
                  color: AppColors.grey400,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
