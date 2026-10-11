import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/pages/search/move_in_inspection_page.dart';
import 'package:roost_app/theme/app_colors.dart';

/// Prompt card displayed on the property detail page allowing tenants
/// to launch a Digital Move-in Inspection for this listing.
class InspectionActionCard extends StatelessWidget {
  const InspectionActionCard({super.key, required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.white.withAlpha(12),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white.withAlpha(25)),
                ),
                child: const Icon(
                  Icons.checklist_rounded,
                  color: AppColors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Move-in Inspection',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Digital deposit protection report',
                      style: TextStyle(
                        color: AppColors.grey500,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Description ─────────────────────────────────────────────
          const Text(
            'Protect your deposit with a room-by-room condition report. '
            'Document walls, plumbing, appliances, and meter readings with '
            'photo evidence before you move in.',
            style: TextStyle(
              color: AppColors.grey400,
              fontSize: 13,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 12),

          // ── Feature pills ───────────────────────────────────────────
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FeaturePill(icon: Icons.camera_alt_outlined, label: 'Photo Evidence'),
              _FeaturePill(icon: Icons.electric_meter_outlined, label: 'Meter Readings'),
              _FeaturePill(icon: Icons.draw_outlined, label: 'Digital Sign-off'),
              _FeaturePill(icon: Icons.share_outlined, label: 'Shareable Report'),
            ],
          ),

          const SizedBox(height: 18),

          // ── CTA Button ──────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MoveInInspectionPage(property: property),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.white,
                foregroundColor: AppColors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow_rounded, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Start Inspection',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Feature pill
// ──────────────────────────────────────────────────────────────────────────────

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.grey400, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.grey300,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
