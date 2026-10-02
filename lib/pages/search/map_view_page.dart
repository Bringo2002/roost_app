import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roost_app/l10n/generated/app_localizations.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/pages/search/property_detail_page.dart';
import 'package:roost_app/services/location_service.dart';
import 'package:roost_app/theme/app_map_style.dart';

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

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
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
        backgroundColor: const Color(0xFF2C2C2E),
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
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(geoProperties.first.latitude!,
                        geoProperties.first.longitude!),
                    zoom: 12,
                  ),
                  style: AppMapStyle.darkMapStyle,
                  buildingsEnabled: true,
                  mapToolbarEnabled: false,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    AppMapStyle.checkStyleApplied(controller);
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
