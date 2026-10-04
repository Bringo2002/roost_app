import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:roost_app/theme/app_colors.dart';

/// A frosted-glass circular button -- `BackdropFilter` blur behind a
/// translucent scrim -- used for controls that float over photo content
/// of unpredictable brightness (back/favorite/share on the hero, mute on
/// the video slide). Reads clearly over both a dark night photo and a
/// bright daylight one, which a flat `Colors.black45` circle doesn't
/// always manage.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color,
    this.child,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  /// Overrides [icon] entirely when the button needs a custom child
  /// (e.g. an animated favorite heart) rather than a plain static icon.
  final Widget? child;

  /// Accessibility label (also the long-press tooltip). The button is
  /// icon-only, so a screen reader has nothing to announce without one.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            tooltip: tooltip,
            onPressed: onTap,
            icon: child ?? Icon(icon, color: color ?? AppColors.white, size: 20),
          ),
        ),
      ),
    );
  }
}
