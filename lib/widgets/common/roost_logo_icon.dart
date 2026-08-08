import 'package:flutter/material.dart';

/// Roost Official Brand Logo Icon (#7 - Property Point)
/// Renders the icon mark directly -- transparent background, white glyph --
/// so it sits straight on the app's own black background rather than
/// inside a separate white card.
class RoostLogoIcon extends StatelessWidget {
  final double size;

  const RoostLogoIcon({
    super.key,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icon/roost_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
