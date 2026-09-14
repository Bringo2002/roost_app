import 'package:flutter/material.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/theme/app_colors.dart';

/// The three quick-stat cards (bedrooms, bathrooms, house type) shown
/// under the verification badges.
class QuickStatsRow extends StatelessWidget {
  const QuickStatsRow({super.key, required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _QuickStatCard(icon: Icons.king_bed_outlined, title: property.bedroomDisplay, subtitle: 'Bedrooms'),
        const SizedBox(width: 10),
        _QuickStatCard(icon: Icons.bathtub_outlined, title: '${property.bathrooms} Bath', subtitle: 'Bathrooms'),
        const SizedBox(width: 10),
        _QuickStatCard(icon: Icons.home_work_outlined, title: property.houseType.isNotEmpty ? property.houseType : 'Apartment', subtitle: 'Type'),
      ],
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  const _QuickStatCard({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.white, size: 22),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: AppColors.grey500, fontSize: 11), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
