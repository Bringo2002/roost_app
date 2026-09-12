import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Pixel-perfect shimmer skeleton that mirrors [PropertyCard]'s layout.
///
/// Shown in place of a [CircularProgressIndicator] while the feed loads —
/// eliminates the jarring blank-screen flash and communicates progress
/// in the same visual language as the real content.
class PropertyCardSkeleton extends StatelessWidget {
  const PropertyCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Shimmer.fromColors(
        baseColor: const Color(0xFF1C1C1E),
        highlightColor: const Color(0xFF2C2C2E),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image placeholder
            Container(
              height: 185,
              width: double.infinity,
              color: const Color(0xFF2C2C2E),
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + availability pill
                  Row(
                    children: [
                      _block(width: 180, height: 17),
                      const Spacer(),
                      _block(width: 60, height: 18),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Location
                  _block(width: 140, height: 13),
                  const SizedBox(height: 12),

                  // Price + house type badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _block(width: 120, height: 20),
                      _block(width: 65, height: 22),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Amenity chips row
                  Row(
                    children: [
                      _block(width: 55, height: 16),
                      const SizedBox(width: 6),
                      _block(width: 55, height: 16),
                      const SizedBox(width: 6),
                      _block(width: 45, height: 16),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                  const SizedBox(height: 12),

                  // Action buttons: 2 icon squares + 1 primary CTA
                  Row(
                    children: [
                      _block(width: 40, height: 40),
                      const SizedBox(width: 8),
                      _block(width: 40, height: 40),
                      const SizedBox(width: 10),
                      Expanded(child: _block(height: 40)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _block({double? width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
