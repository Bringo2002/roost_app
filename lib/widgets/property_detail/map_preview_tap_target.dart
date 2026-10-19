import 'package:flutter/material.dart';
import 'package:roost_app/l10n/generated/app_localizations.dart';

/// The transparent tap area laid over the property detail page's map preview.
///
/// The preview itself is not interactive (every map gesture is off), so it is
/// hidden from assistive technology; this is the one control a screen reader
/// finds there. It announces what the map shows and, as a hint, what tapping
/// it does, and it opens the full-screen map via [onTap].
class MapPreviewTapTarget extends StatelessWidget {
  const MapPreviewTapTarget({super.key, required this.onTap});

  /// Called when the preview is tapped, or activated by a screen reader.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: l10n.propertyDetailMapPreviewLabel,
      hint: l10n.propertyDetailMapPreviewHint,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap),
      ),
    );
  }
}
