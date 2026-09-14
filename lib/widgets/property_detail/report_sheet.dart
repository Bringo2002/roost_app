import 'package:flutter/material.dart';
import 'package:roost_app/controllers/property_detail_controller.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/widgets/property_detail/roost_bottom_sheet.dart';

/// Lets a renter flag a listing as fake, mispriced, unavailable, or
/// otherwise wrong. Reason is a fixed set rather than free text so
/// reports are triageable in bulk on the backend.
class ReportSheet extends StatefulWidget {
  const ReportSheet({super.key, required this.controller});

  final PropertyDetailController controller;

  static const List<String> reasons = [
    'Fake listing',
    'Incorrect price / hidden fees',
    'Already taken / not available',
    'Fraud or scam attempt',
    'Inaccurate photos / location',
    'Other',
  ];

  static Future<void> show(BuildContext context, PropertyDetailController controller) {
    return RoostBottomSheet.show(
      context: context,
      title: 'Report Listing',
      subtitle: 'Help us keep Roost safe and verified. Why are you reporting this property?',
      builder: (_) => ReportSheet(controller: controller),
    );
  }

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  String _selectedReason = ReportSheet.reasons.first;
  bool _isSubmitting = false;

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      await widget.controller.reportProperty(_selectedReason);
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted. Thank you for keeping Roost safe!'),
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit: ${e is ApiException ? e.message : e}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...ReportSheet.reasons.map((r) {
          final selected = _selectedReason == r;
          return ListTile(
            title: Text(
              r,
              style: TextStyle(color: selected ? AppColors.textPrimary : AppColors.textTertiary, fontSize: 14),
            ),
            trailing: Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.white : AppColors.grey500,
              size: 20,
            ),
            contentPadding: EdgeInsets.zero,
            onTap: _isSubmitting ? null : () => setState(() => _selectedReason = r),
          );
        }),
        const SizedBox(height: 12),
        RoostSheetSubmitButton(
          label: 'Submit Report',
          isSubmitting: _isSubmitting,
          isDestructive: true,
          onPressed: _submit,
        ),
      ],
    );
  }
}
