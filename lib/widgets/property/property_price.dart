import 'package:flutter/material.dart';
import 'package:roost_app/theme/app_text_styles.dart';
import 'package:roost_app/services/country_service.dart';

class PropertyPrice extends StatelessWidget {
  const PropertyPrice({
    super.key,
    required this.amount,
    this.currency,
    this.periodSuffix,
    this.style,
    this.compact = false,
  });

  final num amount;
  final String? currency;
  final String? periodSuffix;

  /// Overrides the default price style entirely, if provided.
  final TextStyle? style;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final formatted = currency != null
        ? '$currency ${CountryService.instance.formatNumber(amount)}'
        : CountryService.price(amount);
    final effectiveStyle =
        style ?? (compact ? AppTextStyles.priceCompact : AppTextStyles.price);

    return Text(
      '$formatted${periodSuffix != null ? ' /$periodSuffix' : ''}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: effectiveStyle,
    );
  }
}
