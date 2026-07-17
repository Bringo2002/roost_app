import 'package:flutter/material.dart';

class PropertyLocation extends StatelessWidget {
  const PropertyLocation({
    super.key,
    required this.location,
    this.compact = false,
    this.iconColor,
    this.textColor,
  });

  final String location;
  final bool compact;
  final Color? iconColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.location_on,
          size: compact ? 13 : 14,
          color: iconColor ?? (compact ? Colors.grey[600] : Colors.grey[500]),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            location,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color:
                  textColor ?? (compact ? Colors.grey[500] : Colors.grey[400]),
              fontSize: compact ? 12 : 13,
            ),
          ),
        ),
      ],
    );
  }
}
