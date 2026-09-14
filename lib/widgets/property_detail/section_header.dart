import 'package:flutter/material.dart';
import 'package:roost_app/theme/app_text_styles.dart';

/// A single-line section title (e.g. "Amenities", "Location", "Landlord").
/// Exists so every section heading on the detail page shares one style
/// definition instead of six inline `Text(..., style: TextStyle(...))`
/// literals that can silently drift apart over time.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.label, {super.key, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    if (trailing == null) {
      return Text(label, style: AppTextStyles.sectionHeader);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.sectionHeader),
        trailing!,
      ],
    );
  }
}
