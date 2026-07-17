import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PropertyPrice extends StatelessWidget {
  const PropertyPrice({
    super.key,
    required this.amount,
    this.currency = 'KES',
    this.periodSuffix,
    this.fontSize = 18,
    this.fontWeight = FontWeight.bold,
    this.color = Colors.white,
  });

  final num amount;
  final String currency;
  final String? periodSuffix;
  final double fontSize;
  final FontWeight fontWeight;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final formatted = NumberFormat('#,##0').format(amount);

    return Text(
      '$currency $formatted${periodSuffix != null ? ' /$periodSuffix' : ''}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
      ),
    );
  }
}
