import 'package:flutter/material.dart';
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
          // Header
          const Row(
            children: [
              Icon(Icons.checklist_rounded, color: AppColors.white, size: 22),
              SizedBox(width: 8),
              Text(
                'Move-in Inspection',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Description
          Text(
            'Protect your deposit with a room-by-room condition report. '
            'Document walls, plumbing, appliances, and meter readings with '
            'photo evidence before you move in.',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 8),

          // Feature pills
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPill(Icons.camera_alt_outlined, 'Photo Evidence'),
              _buildPill(Icons.electric_meter_outlined, 'Meter Readings'),
              _buildPill(Icons.edit_outlined, 'Digital Sign-off'),
              _buildPill(Icons.share_outlined, 'Shareable Report'),
            ],
          ),

          const SizedBox(height: 16),

          // CTA Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _startInspection(context),
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

  Widget _buildPill(IconData icon, String label) {
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

  void _startInspection(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MoveInInspectionPage(property: property),
      ),
    );
  }
}
