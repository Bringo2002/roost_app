import 'package:flutter/material.dart';
import 'package:roost_app/controllers/property_detail_controller.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/widgets/property_detail/roost_bottom_sheet.dart';

/// Detail codes for viewing-fee violations. Enum prevents string
/// drift and lets the backend switch on a stable key.
enum ViewingFeeDetail {
  askedBeforeViewing('Asked to pay before viewing'),
  chargedDuring('Charged during the viewing'),
  chargedAfter('Charged after the viewing'),
  depositDemanded('Deposit demanded before seeing the unit'),
  otherFee('Other fee requested');

  const ViewingFeeDetail(this.label);
  final String label;
}

/// Lets a renter flag that they were asked to pay for a viewing --
/// something Roost's policy explicitly prohibits. Routes through the
/// [PropertyDetailController] so every report endpoint is centralised
/// in one place, matching [ReportSheet].
class ReportViewingFeeSheet extends StatefulWidget {
  const ReportViewingFeeSheet({super.key, required this.controller});

  final PropertyDetailController controller;

  static Future<void> show(BuildContext context, PropertyDetailController controller) {
    return RoostBottomSheet.show(
      context: context,
      title: 'Report Viewing Fee',
      subtitle: 'Property viewings on Roost are always free. If someone asked you to pay, let us know so we can take action.',
      builder: (_) => ReportViewingFeeSheet(controller: controller),
    );
  }

  @override
  State<ReportViewingFeeSheet> createState() => _ReportViewingFeeSheetState();
}

class _ReportViewingFeeSheetState extends State<ReportViewingFeeSheet> {
  ViewingFeeDetail _selected = ViewingFeeDetail.askedBeforeViewing;
  bool _isSubmitting = false;

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.controller.reportViewingFee(_selected.label);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Report submitted. We take viewing fees very seriously.'),
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not submit report: ${e is ApiException ? e.message : e}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RoostRadioList<ViewingFeeDetail>(
          options: ViewingFeeDetail.values,
          labelOf: (d) => d.label,
          selected: _selected,
          onChanged: (d) => setState(() => _selected = d),
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
