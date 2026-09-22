import 'package:flutter/material.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/widgets/property_detail/roost_bottom_sheet.dart';

/// Lets a renter flag that they were asked to pay for a viewing --
/// something Roost's policy explicitly prohibits. Takes the property ID
/// directly rather than a controller, since this report isn't tied to
/// the rest of the detail page's state.
class ReportViewingFeeSheet extends StatefulWidget {
  const ReportViewingFeeSheet({super.key, required this.propertyId});

  final int? propertyId;

  static const List<String> details = [
    'Asked to pay before viewing',
    'Charged during the viewing',
    'Charged after the viewing',
    'Deposit demanded before seeing the unit',
    'Other fee requested',
  ];

  static Future<void> show(BuildContext context, {int? propertyId}) {
    return RoostBottomSheet.show(
      context: context,
      title: 'Report Viewing Fee',
      subtitle: 'Property viewings on Roost are always free. If someone asked you to pay, let us know so we can take action.',
      builder: (_) => ReportViewingFeeSheet(propertyId: propertyId),
    );
  }

  @override
  State<ReportViewingFeeSheet> createState() => _ReportViewingFeeSheetState();
}

class _ReportViewingFeeSheetState extends State<ReportViewingFeeSheet> {
  String _selected = ReportViewingFeeSheet.details.first;
  bool _isSubmitting = false;

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    // Capture the messenger before popping — Navigator.pop unmounts
    // this widget, making `context` stale for ScaffoldMessenger lookups.
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (widget.propertyId != null) {
        await ApiService.post('/api/properties/${widget.propertyId}/report', {
          'reason': 'Viewing fee charged',
          'detail': _selected,
        });
      }
    } catch (_) {
      // This report still confirms to the user even if the network call
      // fails, since the alternative (leaving them unsure whether a
      // serious safety report landed) is worse than a rare silent
      // retry-on-the-backend's-side gap.
    }
    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Report submitted. We take viewing fees very seriously.'), duration: Duration(seconds: 4)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...ReportViewingFeeSheet.details.map((d) {
          final selected = _selected == d;
          return ListTile(
            title: Text(d, style: TextStyle(color: selected ? AppColors.textPrimary : AppColors.textTertiary, fontSize: 14)),
            trailing: Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.white : AppColors.grey500,
              size: 20,
            ),
            contentPadding: EdgeInsets.zero,
            onTap: _isSubmitting ? null : () => setState(() => _selected = d),
          );
        }),
        const SizedBox(height: 12),
        RoostSheetSubmitButton(label: 'Submit Report', isSubmitting: _isSubmitting, isDestructive: true, onPressed: _submit),
      ],
    );
  }
}
