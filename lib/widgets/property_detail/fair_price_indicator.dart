import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/theme/app_colors.dart';

class FairPriceIndicator extends StatelessWidget {
  const FairPriceIndicator({super.key, required this.property});

  final Property property;

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

    // Clamp between -50% and +50% for the slider position
    final clampedDiff = diff.clamp(-50.0, 50.0);
    // Convert to 0.0 -> 1.0 (0.0 is -50%, 1.0 is +50%)
    final alignment = (clampedDiff + 50) / 100;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Based on $sampleSize similar listings nearby. Average rent: ${property.priceComparisonAverage!.round()}.',
              style: const TextStyle(fontSize: 13),
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.grey400, size: 14),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(color: AppColors.grey400, fontSize: 12.5, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: const LinearGradient(
                  colors: [AppColors.success, AppColors.warning, AppColors.error],
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: -4,
                    child: Align(
                      alignment: FractionalOffset(alignment, 0),
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.black, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Cheaper', style: TextStyle(color: AppColors.grey500, fontSize: 10)),
                Text('More expensive', style: TextStyle(color: AppColors.grey500, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
