import 'package:flutter/material.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/theme/app_text_styles.dart';

class PropertyLocation extends StatelessWidget {
  const PropertyLocation({
    super.key,
    required this.location,
    this.compact = false,
  });

  final String location;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.location_on_outlined,
          size: compact ? 13 : 14,
          color: AppColors.textTertiary,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            location,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.location.copyWith(
              fontSize: compact ? 12 : 14,
            ),
          ),
        ),
      ],
    );
  }
}
