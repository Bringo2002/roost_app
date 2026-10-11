import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:roost_app/controllers/property_detail_controller.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/widgets/property_detail/report_viewing_fee_sheet.dart';

/// The "Roost prohibits charging for viewings" trust banner. Previously
/// teal-accented (`AppColors.landlordAccent`) -- now a plain white-bordered
/// card, consistent with the rest of the monochrome trust UI.
///
/// Takes a [PropertyDetailController] so the report flows through the
/// same centralised API layer as every other action on the detail page.
class FreeViewingsBanner extends StatelessWidget {
  const FreeViewingsBanner({super.key, required this.controller});

  final PropertyDetailController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: AppColors.white, size: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '100% Free Viewings Guarantee',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Roost prohibits charging for property viewings. Report any fees.',
                  style: TextStyle(color: AppColors.grey400, fontSize: 10.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                ReportViewingFeeSheet.show(context, controller);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.grey600),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Report',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
