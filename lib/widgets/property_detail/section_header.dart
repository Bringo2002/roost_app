import 'package:flutter/material.dart';
import 'package:roost_app/theme/app_text_styles.dart';

/// A single-line section title (e.g. "Amenities", "Location", "Landlord").
/// Exists so every section heading on the detail page shares one style
/// definition instead of six inline `Text(..., style: TextStyle(...))`
/// literals that can silently drift apart over time.
///
/// The label is exposed to assistive technology as a heading, so screen-reader
/// users can jump between sections. A [trailing] control stays a separate,
/// non-heading element.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.label, {super.key, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final title = Semantics(
      container: true,
      header: true,
      label: label,
      excludeSemantics: true,
      child: Text(label, style: AppTextStyles.sectionHeader),
    );
    if (trailing == null) {
      return title;
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        title,
        trailing!,
      ],
    );
  }
}
