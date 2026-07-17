import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:roost_app/theme/app_text_styles.dart';

class PropertyPrice extends StatelessWidget {
  const PropertyPrice({
    super.key,
    required this.amount,
    this.currency = 'KES',
    this.periodSuffix,
    this.style,
    this.compact = false,
  });

  final num amount;
  final String currency;
  final String? periodSuffix;

  /// Overrides the default price style entirely, if provided.
  final TextStyle? style;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final formatted = NumberFormat('#,##0').format(amount);
    final effectiveStyle =
        style ?? (compact ? AppTextStyles.priceCompact : AppTextStyles.price);

    return Text(
      '$currency $formatted${periodSuffix != null ? ' /$periodSuffix' : ''}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: effectiveStyle,
    );
  }
}
