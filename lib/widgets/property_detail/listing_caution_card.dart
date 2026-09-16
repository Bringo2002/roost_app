import 'package:flutter/material.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/widgets/property_detail/roost_bottom_sheet.dart';

/// Shown when a listing has one or more server-computed caution flags
/// (PropertyRiskService on the backend -- report history, negative
/// community-check ratio, or a price well below comparable listings).
/// Renders nothing when there's nothing to flag, the same "only speak
/// up when there's something to say" principle [VerificationBadges]
/// already follows for GPS/document badges.
///
/// Deliberately a different visual language from the positive trust
/// badges elsewhere on this page: not the solid-white "verified" fill,
/// not the plain grey-outline "informational" pill -- a firmer grey700
/// border and a warning icon signal "pay attention" without reaching
/// for a color the rest of the app doesn't use.
class ListingCautionCard extends StatelessWidget {
  const ListingCautionCard({super.key, required this.riskFlags});

  final List<String> riskFlags;

  static const Map<String, _FlagCopy> _copy = {
    'REPORTED': _FlagCopy(
      title: 'Recently reported',
      detail: 'One or more renters have flagged an issue with this listing. '
          "It hasn't been enough reports to remove it automatically, but "
          'worth reading up before you commit to anything.',
    ),
    'COMMUNITY_INACCURATE': _FlagCopy(
      title: 'Mixed visitor feedback',
      detail: 'Several renters who visited said this listing didn\'t fully '
          'match what was advertised -- photos, location, or price.',
    ),
    'PRICE_BELOW_MARKET': _FlagCopy(
      title: 'Price well below similar listings',
      detail: 'This price is notably lower than comparable listings nearby. '
          "That's sometimes a genuine deal, but it's also a common pattern "
          'in scam listings -- verify everything before sending any money.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final known = riskFlags.where(_copy.containsKey).toList();
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
          Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.white, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Worth double-checking',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            known.map((f) => _copy[f]!.title).join(' · '),
            style: TextStyle(color: AppColors.grey300, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _showDetails(context, known),
            child: const Text(
              'Learn more',
              style: TextStyle(color: AppColors.white, fontSize: 12.5, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetails(BuildContext context, List<String> known) {
    RoostBottomSheet.show(
      context: context,
      title: 'Worth double-checking',
      subtitle: "Here's what our system flagged about this listing -- none of these mean it's definitely a problem, just worth a closer look.",
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final flag in known) ...[
            Row(
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
                      Text(_copy[flag]!.title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 3),
                      Text(_copy[flag]!.detail, style: TextStyle(color: AppColors.grey400, fontSize: 12.5, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
            if (flag != known.last) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _FlagCopy {
  const _FlagCopy({required this.title, required this.detail});
  final String title;
  final String detail;
}
