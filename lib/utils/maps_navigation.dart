import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:roost_app/l10n/generated/app_localizations.dart';
import 'package:roost_app/theme/app_colors.dart';

/// Opens Google Maps with turn-by-turn directions to [lat],[lng] -- no
/// chooser. Tries the Google Maps app first, falls back to the web page in
/// a browser, and shows a snackbar (rather than silently doing nothing) if
/// neither can be opened.
Future<void> launchGoogleMapsNavigation(
  BuildContext context, {
  required double lat,
  required double lng,
}) async {
  final mapsUri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
  );
  try {
    final launchedApp = await launchUrl(mapsUri, mode: LaunchMode.externalNonBrowserApplication);
    if (launchedApp) return;
    final launchedBrowser = await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
    if (!launchedBrowser) throw Exception('No app or browser could handle the maps link');
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.inAppMapNavigationFailed),
        backgroundColor: AppColors.surfaceContainerHigh,
      ),
    );
  }
}
