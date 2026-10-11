import 'package:flutter/material.dart';
import 'package:roost_app/controllers/property_detail_controller.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/widgets/property_detail/roost_bottom_sheet.dart';

/// Reason codes for flagging a listing. Using an enum prevents typos
/// in the reason string and makes it trivial to add analytics or
/// server-side mapping later.
enum ReportReason {
  fakeListing('Fake listing'),
  incorrectPrice('Incorrect price / hidden fees'),
  alreadyTaken('Already taken / not available'),
  fraudOrScam('Fraud or scam attempt'),
  inaccurateMedia('Inaccurate photos / location'),
  other('Other');

  const ReportReason(this.label);
  final String label;
}

/// Lets a renter flag a listing as fake, mispriced, unavailable, or
/// otherwise wrong. Reason is a fixed enum so reports are triageable
/// in bulk on the backend.
class ReportSheet extends StatefulWidget {
  const ReportSheet({super.key, required this.controller});

  final PropertyDetailController controller;

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
  ReportReason _selected = ReportReason.fakeListing;
  bool _isSubmitting = false;

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.controller.reportProperty(_selected.label);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Report submitted. Thank you for keeping Roost safe!'),
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
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
        RoostRadioList<ReportReason>(
          options: ReportReason.values,
          labelOf: (r) => r.label,
          selected: _selected,
          onChanged: (r) => setState(() => _selected = r),
          enabled: !_isSubmitting,
        ),
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
