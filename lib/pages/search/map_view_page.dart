import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roost_app/l10n/generated/app_localizations.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/pages/search/property_detail_page.dart';
import 'package:roost_app/services/location_service.dart';
import 'package:roost_app/theme/app_colors.dart';

/// Shows the current search results as pins on a map instead of a list --
/// the "browse on map" mode search apps like this are usually judged
/// against. This existed before as a fully working widget, just never
/// reachable from anywhere in the app (no button anywhere pushed it);
/// SearchPage's map-toggle button is what makes it reachable.
class MapViewPage extends StatefulWidget {
  final List<Property> properties;

  const MapViewPage({super.key, required this.properties});

  @override
  State<MapViewPage> createState() => _MapViewPageState();
}

class _MapViewPageState extends State<MapViewPage> {
  GoogleMapController? _mapController;
  bool _centeredOnUser = false;

  /// See the matching fields on InAppMapPage for why this exists: the
  /// Google Maps SDK has no onMapCreated-failed callback, so this is a
  /// best-effort "it's been too long" fallback rather than a diagnosed
  /// error.
  static const _mapLoadTimeout = Duration(seconds: 10);
  bool _mapReady = false;
  bool _mapLoadTimedOut = false;
  int _mapInstanceKey = 0;
  Timer? _mapLoadTimer;

  @override
  void initState() {
    super.initState();
    _startMapLoadTimer();
  }

  @override
  void dispose() {
    _mapLoadTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _startMapLoadTimer() {
    _mapLoadTimer?.cancel();
    _mapLoadTimer = Timer(_mapLoadTimeout, () {
      if (!mounted || _mapReady) return;
      setState(() => _mapLoadTimedOut = true);
    });
  }

  void _retryMapLoad() {
    setState(() {
      _mapReady = false;
      _mapLoadTimedOut = false;
      _mapInstanceKey++; // forces GoogleMap to remount with a fresh native view
    });
    _startMapLoadTimer();
  }

  /// Called from onMapCreated, once _mapController actually exists --
  /// this used to also be called from initState, which raced two
  /// concurrent LocationService.getCurrentPosition() calls and could
  /// mean two permission prompts and two GPS reads for one screen.
  Future<void> _centerOnUserLocation() async {
    final position = await LocationService.getCurrentPosition();
    if (position == null || !mounted) return;
    setState(() => _centeredOnUser = true);
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude), 13),
    );
  }

  /// Handles the location button when centering hasn't happened (yet, or
  /// at all) -- previously this used Google's own built-in location
  /// button, which on denied/disabled permission just silently does
  /// nothing with no indication why or how to fix it. Mirrors the same
  /// pattern InAppMapPage uses for its "center on me" button.
  Future<void> _handleLocationButtonTap() async {
    if (_centeredOnUser) {
      await _centerOnUserLocation();
      return;
    }
    final status = await LocationService.checkPermissionStatus();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    switch (status) {
      case LocationPermissionStatus.serviceDisabled:
        _showEnableLocationPrompt(
          l10n.mapEnableLocationServices,
          LocationService.openLocationSettings,
        );
        break;
      case LocationPermissionStatus.deniedForever:
        _showEnableLocationPrompt(
          l10n.mapEnableLocationPermission,
          LocationService.openAppSettings,
        );
        break;
      case LocationPermissionStatus.denied:
      case LocationPermissionStatus.granted:
        // Either retryable-in-app or a transient failure -- just retry.
        await _centerOnUserLocation();
        break;
    }
  }

  void _showEnableLocationPrompt(String message, Future<void> Function() onOpenSettings) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.surfaceContainerHigh,
        action: SnackBarAction(
          label: AppLocalizations.of(context)!.inAppMapOpenSettings,
          textColor: Colors.white,
          onPressed: () {
            onOpenSettings();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final geoProperties = widget.properties
        .where((p) => p.latitude != null && p.longitude != null)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${geoProperties.length} on map',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: geoProperties.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined, color: Colors.grey[700], size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'No properties in these results have\nlocation coordinates yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                Semantics(
                  label: AppLocalizations.of(context)!.mapViewSemanticLabel(geoProperties.length),
                  child: GoogleMap(
                    key: ValueKey('browse_map_$_mapInstanceKey'),
                    initialCameraPosition: CameraPosition(
                      target: LatLng(geoProperties.first.latitude!,
                          geoProperties.first.longitude!),
                      zoom: 12,
                    ),
                    // No custom style: Google's own colors/icons/labels.
                    buildingsEnabled: true,
                    mapToolbarEnabled: false,
                    // Explicit even though true is the plugin default --
                    // this was previously unset here while InAppMapPage
                    // explicitly disabled it, an inconsistency that's
                    // easy to miss when the setting is left implicit.
                    // Android only; silently ignored on iOS.
                    zoomControlsEnabled: true,
                    onMapCreated: (controller) {
                      _mapController = controller;
                      _mapLoadTimer?.cancel();
                      if (mounted) setState(() => _mapReady = true);
                      _centerOnUserLocation();
                    },
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    markers: geoProperties.map((p) {
                      return Marker(
                        markerId: MarkerId('property-${p.id}'),
                        position: LatLng(p.latitude!, p.longitude!),
                        // No InfoWindow text: tapping a pin always navigates
                        // straight to the property's detail page below, so a
                        // title/location bubble would only flash on screen
                        // for an instant before being replaced by that page.
                        infoWindow: InfoWindow.noText,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PropertyDetailPage(property: p),
                            ),
                          );
                        },
                      );
                    }).toSet(),
                  ),
                ),
                if (!_mapReady) _MapLoadOverlay(timedOut: _mapLoadTimedOut, onRetry: _retryMapLoad),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: _MapCircleButton(
                    icon: _centeredOnUser ? Icons.my_location : Icons.location_disabled,
                    semanticLabel: _centeredOnUser
                        ? AppLocalizations.of(context)!.inAppMapCenterOnUser
                        : AppLocalizations.of(context)!.inAppMapLocationUnavailable,
                    onTap: _handleLocationButtonTap,
                  ),
                ),
              ],
            ),
    );
  }
}

/// Circular icon button with a guaranteed 44x44 hit target and a Semantics
/// label, instead of a bare IconButton/GestureDetector -- same
/// accessibility rationale as the equivalent private widget in
/// InAppMapPage, duplicated here rather than shared since each map page
/// currently keeps its own small UI-only widgets local to itself.
class _MapCircleButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  const _MapCircleButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.black.withValues(alpha: 0.9),
        shape: CircleBorder(side: BorderSide(color: Colors.grey[800]!)),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(child: Icon(icon, color: Colors.white, size: 22)),
          ),
        ),
      ),
    );
  }
}

/// Covers the map while it's initializing (solid black, matching the
/// app's own chrome, so there's no flash of an empty frame before tiles
/// arrive), or shows a retry option if it never finished within the load
/// timeout. See _MapViewPageState's timeout fields for why this exists
/// rather than reacting to a specific SDK error.
class _MapLoadOverlay extends StatelessWidget {
  final bool timedOut;
  final VoidCallback onRetry;

  const _MapLoadOverlay({required this.timedOut, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black,
        child: Center(
          child: timedOut
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_outlined, color: Colors.grey[600], size: 48),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        AppLocalizations.of(context)!.mapLoadFailed,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[400], fontSize: 15),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: onRetry,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.grey[700]!),
                      ),
                      child: Text(AppLocalizations.of(context)!.mapRetry),
                    ),
                  ],
                )
              : const CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }
}
