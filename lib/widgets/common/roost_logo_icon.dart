import 'package:flutter/material.dart';

/// Roost Official Brand Logo Icon (#7 - Property Point)
/// Renders the exact pixel-perfect PNG asset.
class RoostLogoIcon extends StatelessWidget {
  final double size;

  const RoostLogoIcon({
    super.key,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'assets/icon/roost_logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}
