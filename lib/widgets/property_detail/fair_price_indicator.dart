import 'package:flutter/material.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/theme/app_colors.dart';

/// A single-line "how does this price compare?" indicator, computed
/// server-side from listings with the same house type, bedroom count,
/// and location (see PropertyRiskService.getPriceComparison on the
/// backend). Deliberately compact and inline rather than a full card --
/// this is a quick fact to read once, not something that needs its own
/// visual weight, the same way Zillow/Redfin show a price estimate
/// inline near the price rather than in a separate panel.
///
/// Renders nothing when the backend didn't find any comparable listings
/// -- a comparison against zero data points isn't useful information,
/// it's noise.
class FairPriceIndicator extends StatelessWidget {
  const FairPriceIndicator({super.key, required this.property});

  final Property property;

  /// Below this magnitude, the difference reads as "basically the
  /// same price" rather than meaningfully above or below -- avoids
  /// reporting something like "3% above average" as if it were a
  /// finding worth a tenant's attention.
  static const double _neutralBandPercent = 15;

  @override
  Widget build(BuildContext context) {
    final avg = property.priceComparisonAverage;
    final sampleSize = property.priceComparisonSampleSize;
    final diff = property.priceComparisonPercentDiff;
    if (avg == null || diff == null || sampleSize == null || sampleSize == 0) {
      return const SizedBox.shrink();
    }

    final IconData icon;
    final String label;
    if (diff <= -_neutralBandPercent) {
      icon = Icons.arrow_downward;
      label = '${diff.abs().round()}% below similar listings nearby';
    } else if (diff >= _neutralBandPercent) {
      icon = Icons.arrow_upward;
      label = '${diff.round()}% above similar listings nearby';
    } else {
      icon = Icons.check;
      label = 'In line with similar listings nearby';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.grey400, size: 14),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: AppColors.grey400, fontSize: 12.5, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
