import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:roost_app/theme/app_colors.dart';

/// A frosted-glass circular button -- `BackdropFilter` blur behind a
/// translucent scrim -- used for controls that float over photo content
/// of unpredictable brightness (back/favorite/share on the hero, mute on
/// the video slide). Reads clearly over both a dark night photo and a
/// bright daylight one, which a flat `Colors.black45` circle doesn't
/// always manage.
///
/// The button is [size] logical pixels square, the minimum comfortable touch
/// target. Its parent must not constrain it below that: an app bar's `leading`
/// slot is 56 wide, so it needs at most 6 of padding per side, not 8.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color,
    this.child,
    this.tooltip,
  });

  /// Width and height of the button, and so of its touch target.
  static const double size = 44;

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
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.glassFill,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.glassBorder),
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
