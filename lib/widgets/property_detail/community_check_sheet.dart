import 'package:flutter/material.dart';
import 'package:roost_app/controllers/property_detail_controller.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/widgets/property_detail/roost_bottom_sheet.dart';

/// The tenant-facing "did this listing match what was advertised?" prompt.
/// Only ever shown for tenants the backend has independently confirmed
/// applied to this listing -- see [PropertyDetailController].
class CommunityCheckSheet extends StatefulWidget {
  const CommunityCheckSheet({super.key, required this.controller});

  final PropertyDetailController controller;

  static Future<void> show(BuildContext context, PropertyDetailController controller) {
    return RoostBottomSheet.show(
      context: context,
      title: 'Did this listing match?',
      subtitle: 'Since you applied to this listing, your answer helps other renters trust Roost.',
      builder: (_) => CommunityCheckSheet(controller: controller),
    );
  }

  @override
  State<CommunityCheckSheet> createState() => _CommunityCheckSheetState();
}

class _CommunityCheckSheetState extends State<CommunityCheckSheet> {
  bool _visited = true;
  bool _photosAccurate = true;
  bool _locationAccurate = true;
  bool _priceAccurate = true;
  bool _wouldRecommend = true;
  bool _isSubmitting = false;

  Widget _switchTile(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
      value: value,
      onChanged: _isSubmitting ? null : onChanged,
      activeThumbColor: AppColors.white,
      contentPadding: EdgeInsets.zero,
    );
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      await widget.controller.submitCommunityCheck(
        visited: _visited,
        photosAccurate: _photosAccurate,
        locationAccurate: _locationAccurate,
        priceAccurate: _priceAccurate,
        wouldRecommend: _wouldRecommend,
      );
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks for helping keep Roost accurate.')),
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
        _switchTile('I visited or contacted about this property', _visited, (v) => setState(() => _visited = v)),
        if (_visited) ...[
          _switchTile('Photos were accurate', _photosAccurate, (v) => setState(() => _photosAccurate = v)),
          _switchTile('Location was accurate', _locationAccurate, (v) => setState(() => _locationAccurate = v)),
          _switchTile('Price was accurate', _priceAccurate, (v) => setState(() => _priceAccurate = v)),
          _switchTile('I would recommend this listing', _wouldRecommend, (v) => setState(() => _wouldRecommend = v)),
        ],
        const SizedBox(height: 16),
        RoostSheetSubmitButton(
          label: 'Submit',
          isSubmitting: _isSubmitting,
          onPressed: _submit,
        ),
      ],
    );
  }
}
