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
        boxShadow: const [
          BoxShadow(
            color: Color(0x28000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Shimmer.fromColors(
        baseColor: const Color(0xFF2C2C2E),
        highlightColor: const Color(0xFF3A3A3C),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image placeholder
            Container(
              height: 180,
              width: double.infinity,
              color: const Color(0xFF2C2C2E),
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + availability dot
                  Row(
                    children: [
                      _block(width: 180, height: 17),
                      const Spacer(),
                      _block(width: 46, height: 14),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Location
                  _block(width: 140, height: 13),
                  const SizedBox(height: 12),

                  // Price + badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _block(width: 110, height: 18),
                      _block(width: 58, height: 24),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Beds / baths
                  _block(width: 160, height: 13),
                  const SizedBox(height: 14),

                  const Divider(height: 1, color: Color(0xFF2C2C2E)),
                  const SizedBox(height: 12),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(child: _block(height: 36)),
                      const SizedBox(width: 8),
                      Expanded(child: _block(height: 36)),
                      const SizedBox(width: 8),
                      Expanded(child: _block(height: 36)),
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
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
