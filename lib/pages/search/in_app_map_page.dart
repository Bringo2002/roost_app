import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:roost_app/config.dart';
import 'package:roost_app/l10n/generated/app_localizations.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/country_service.dart';
import 'package:roost_app/services/location_service.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/theme/app_map_style.dart';

/// Framework-free description of one marker _buildMarkers would place --
/// no BitmapDescriptor, no GoogleMap dependency -- so the selection logic
/// (property pin only once its icon has loaded; each facility only once
/// its category's icon has loaded) can be unit-tested without spinning up
/// a real map view or loading real image assets.
@visibleForTesting
class MapMarkerSpec {
  final String id;
  final double latitude;
  final double longitude;
  final String title;
  final String? snippet;

  const MapMarkerSpec({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.title,
    this.snippet,
  });

  @override
  bool operator ==(Object other) =>
      other is MapMarkerSpec &&
      other.id == id &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.title == title &&
      other.snippet == snippet;

  @override
  int get hashCode => Object.hash(id, latitude, longitude, title, snippet);

  @override
  String toString() => 'MapMarkerSpec($id @ $latitude,$longitude)';
}

@visibleForTesting
List<MapMarkerSpec> buildMarkerSpecs({
  required Property property,
  required LatLng propertyLatLng,
  required Set<String> loadedFacilityIconCategories,
}) {
  final specs = <MapMarkerSpec>[];

  specs.add(MapMarkerSpec(
    id: 'prop_${property.id}',
    latitude: propertyLatLng.latitude,
    longitude: propertyLatLng.longitude,
    title: property.title,
    snippet: property.location,
  ));

  for (final facility in property.nearbyFacilities) {
    if (!loadedFacilityIconCategories.contains(facility.category)) {
      continue; // icon still loading -- skip this pass
    }
    specs.add(MapMarkerSpec(
      id: 'facility_${facility.category}_${facility.name}',
      latitude: facility.latitude,
      longitude: facility.longitude,
      title: facility.name,
      snippet: facility.label,
    ));
  }

  return specs;
}

class InAppMapPage extends StatefulWidget {
  final Property property;

  const InAppMapPage({super.key, required this.property});

  @override
  State<InAppMapPage> createState() => _InAppMapPageState();
}

class _InAppMapPageState extends State<InAppMapPage> {
  GoogleMapController? _mapController;
  Position? _userPosition;
  double? _distanceKm;

  late final LatLng _propertyLatLng;

  final Map<String, BitmapDescriptor> _facilityIcons = {};

  /// The Google Maps SDK has no onMapCreated-failed/error callback -- if
  /// something stops the native map from ever initializing (no Google
  /// Play Services, no network for tiles, a transient SDK hiccup), the
  /// widget just sits there forever with no signal at all. This is a
  /// best-effort "it's been too long" fallback, not a diagnosed error:
  /// if onMapCreated hasn't fired within [_mapLoadTimeout], show a retry
  /// option instead of leaving the screen looking permanently broken.
  static const _mapLoadTimeout = Duration(seconds: 10);
  bool _mapReady = false;
  bool _mapLoadTimedOut = false;
  int _mapInstanceKey = 0;
  Timer? _mapLoadTimer;

  @override
  void initState() {
    super.initState();
    final hasCoords = widget.property.latitude != null && widget.property.longitude != null;
    _propertyLatLng = hasCoords
        ? LatLng(widget.property.latitude!, widget.property.longitude!)
        : AppConfig.defaultMapCenter;
    _getUserLocationAndDistance();
    _loadMarkerIcons();
    _startMapLoadTimer();
  }

  @override
  void dispose() {
    _mapLoadTimer?.cancel();
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

  /// Custom monochrome pins for nearby facilities (mall/hospital/road) --
  /// these are markers the app itself places, unlike the base map tiles'
  /// own POI icons, so they follow the strict black/white brand. The
  /// property itself uses Google's standard pin.
  ///
  /// Uses BitmapDescriptor.asset (fromAssetImage is deprecated). No
  /// width/height is passed on purpose: the old fromAssetImage ignored
  /// ImageConfiguration.size on Android/iOS (only web honoured it), so the
  /// pins have always rendered at the asset's natural size, while
  /// BitmapDescriptor.asset WOULD apply a configured size and shrink them.
  /// To resize the pins deliberately, pass width:/height: here (the PNGs
  /// are 96x96).
  Future<void> _loadMarkerIcons() async {
    const config = ImageConfiguration();
    final results = await Future.wait([
      BitmapDescriptor.asset(config, 'assets/markers/marker_mall.png'),
      BitmapDescriptor.asset(config, 'assets/markers/marker_hospital.png'),
      BitmapDescriptor.asset(config, 'assets/markers/marker_road.png'),
    ]);
    if (!mounted) return;
    setState(() {
      _facilityIcons['mall'] = results[0];
      _facilityIcons['hospital'] = results[1];
      _facilityIcons['road'] = results[2];
    });
  }

  Future<void> _getUserLocationAndDistance() async {
    final pos = await LocationService.getCurrentPosition();
    if (pos != null && mounted) {
      final distMeters = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        _propertyLatLng.latitude,
        _propertyLatLng.longitude,
      );
      setState(() {
        _userPosition = pos;
        _distanceKm = distMeters / 1000;
      });
    }
  }

  void _recenterOnProperty() {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(_propertyLatLng, 15),
    );
  }

  void _recenterOnUser() {
    if (_userPosition != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_userPosition!.latitude, _userPosition!.longitude),
          14,
        ),
      );
    }
  }

  /// Handles the "center on me" button when there's no position yet --
  /// previously this button simply didn't exist in that case, so denying
  /// location permission silently removed the feature with no way back
  /// short of restarting the app. Now the button always shows (muted,
  /// with a "location disabled" icon) and tapping it explains why and,
  /// where there's something the user can actually do about it, offers
  /// to open the right settings screen.
  Future<void> _handleLocationButtonTap() async {
    if (_userPosition != null) {
      _recenterOnUser();
      return;
    }
    final status = await LocationService.checkPermissionStatus();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    switch (status) {
      case LocationPermissionStatus.serviceDisabled:
        _showEnableLocationPrompt(
          l10n.inAppMapEnableLocationServices,
          LocationService.openLocationSettings,
        );
        break;
      case LocationPermissionStatus.deniedForever:
        _showEnableLocationPrompt(
          l10n.inAppMapEnableLocationPermission,
          LocationService.openAppSettings,
        );
        break;
      case LocationPermissionStatus.denied:
        // Not permanently denied -- retrying in-app re-prompts the OS
        // permission dialog rather than requiring a trip to Settings.
        await _getUserLocationAndDistance();
        break;
      case LocationPermissionStatus.granted:
        // Permission's fine; the earlier null was a transient failure
        // (GPS timeout, etc.) -- just retry rather than claim a settings
        // screen would help.
        await _getUserLocationAndDistance();
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

  /// "Start Navigation" goes straight to Google Maps with the property as
  /// the destination -- no chooser. Tries the Google Maps app first, falls
  /// back to the Google Maps web page in a browser, and shows a message
  /// (instead of silently doing nothing) if neither can be opened.
  Future<void> _launchNavigation() async {
    final lat = _propertyLatLng.latitude;
    final lng = _propertyLatLng.longitude;
    final mapsUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );

    try {
      final launchedApp = await launchUrl(mapsUri, mode: LaunchMode.externalNonBrowserApplication);
      if (launchedApp) return;
      final launchedBrowser = await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
      if (!launchedBrowser) throw Exception('No app or browser could handle the maps link');
    } catch (_) {
      if (!mounted) return;
      _showActionError(AppLocalizations.of(context)!.inAppMapNavigationFailed);
    }
  }

  Future<void> _callLandlord() async {
    final phone = widget.property.landlordPhone;
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    try {
      final launched = await launchUrl(uri);
      if (!launched) throw Exception('tel: launch returned false');
    } catch (_) {
      if (!mounted) return;
      _showActionError(AppLocalizations.of(context)!.inAppMapCallFailed);
    }
  }

  void _showActionError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.surfaceContainerHigh),
    );
  }

  /// Property pin plus one pin per cached nearby facility (mall/hospital/
  /// major road) -- so "600m from TRM Mall" is something you can actually
  /// see on the map relative to the property, not just read as text.
  ///
  /// The property uses Google's standard pin (a custom one looked off at
  /// device pixel densities); facilities use the custom monochrome badges.
  ///
  /// The property marker gets no InfoWindow: the white default-style
  /// tooltip bubble it'd pop up (title + location) just repeats what's
  /// already always on screen in the dark bottom action card, and it
  /// visually clashes as the one light-colored thing on a dark map.
  /// Facility markers keep theirs -- "600m from TRM Mall" isn't shown
  /// anywhere else, so tapping one is the only way to read it.
  ///
  /// The which-markers-to-show logic itself lives in [buildMarkerSpecs]
  /// (framework-free, unit-tested); this just attaches an icon to each spec.
  Set<Marker> _buildMarkers() {
    final specs = buildMarkerSpecs(
      property: widget.property,
      propertyLatLng: _propertyLatLng,
      loadedFacilityIconCategories: _facilityIcons.keys.toSet(),
    );

    final markers = <Marker>{};
    for (final spec in specs) {
      final isProperty = spec.id.startsWith('prop_');
      final icon = isProperty
          ? BitmapDescriptor.defaultMarker
          : _facilityIcons[spec.id.split('_')[1]]!;
      markers.add(
        Marker(
          markerId: MarkerId(spec.id),
          position: LatLng(spec.latitude, spec.longitude),
          infoWindow: isProperty
              ? InfoWindow.noText
              : InfoWindow(title: spec.title, snippet: spec.snippet),
          icon: icon,
          anchor: isProperty ? const Offset(0.5, 1.0) : const Offset(0.5, 0.5),
        ),
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Embedded Dark Google Map ───────────────────────────────────────
          Semantics(
            label: AppLocalizations.of(context)!.inAppMapSemanticLabel(widget.property.title),
            child: GoogleMap(
              key: ValueKey('property_map_$_mapInstanceKey'),
              initialCameraPosition: CameraPosition(
                target: _propertyLatLng,
                zoom: 15,
              ),
              style: AppMapStyle.darkMapStyle,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: true,
              buildingsEnabled: true,
              mapToolbarEnabled: false,
              onMapCreated: (controller) {
                _mapController = controller;
                AppMapStyle.checkStyleApplied(controller);
                _mapLoadTimer?.cancel();
                if (mounted) setState(() => _mapReady = true);
              },
              markers: _buildMarkers(),
              circles: {
                Circle(
                  circleId: CircleId('radius_${widget.property.id}'),
                  center: _propertyLatLng,
                  radius: 400, // 400 meter neighborhood radius highlight
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  strokeColor: Colors.white.withValues(alpha: 0.3),
                  strokeWidth: 2,
                ),
              },
            ),
          ),

          // ── Loading / load-failed states ─────────────────────────────────
          if (!_mapReady) _MapLoadOverlay(timedOut: _mapLoadTimedOut, onRetry: _retryMapLoad),

          // ── Header Bar ────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MapCircleButton(
                    icon: Icons.arrow_back,
                    semanticLabel: AppLocalizations.of(context)!.inAppMapBack,
                    onTap: () => Navigator.pop(context),
                    background: Colors.black,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[800]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _distanceKm != null
                              ? AppLocalizations.of(context)!
                                  .inAppMapDistanceAway(_distanceKm!.toStringAsFixed(1))
                              : widget.property.location,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
          ),

          // ── Floating Recenter Controls ────────────────────────────────────
          Positioned(
            right: 16,
            bottom: 230,
            child: Column(
              children: [
                _MapCircleButton(
                  icon: Icons.home_work_outlined,
                  semanticLabel: AppLocalizations.of(context)!.inAppMapCenterOnProperty,
                  onTap: _recenterOnProperty,
                  background: Colors.black.withValues(alpha: 0.9),
                  borderColor: Colors.grey[800],
                ),
                const SizedBox(height: 10),
                _MapCircleButton(
                  icon: _userPosition != null ? Icons.my_location : Icons.location_disabled,
                  semanticLabel: _userPosition != null
                      ? AppLocalizations.of(context)!.inAppMapCenterOnUser
                      : AppLocalizations.of(context)!.inAppMapLocationUnavailable,
                  onTap: _handleLocationButtonTap,
                  background: Colors.black.withValues(alpha: 0.9),
                  borderColor: Colors.grey[800],
                ),
              ],
            ),
          ),

          // ── Uber-style Bottom Action Card ─────────────────────────────────
          Positioned(
            left: 16,
            right: 16,
            bottom: 30,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey[800]!),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (widget.property.imageUrl != null && widget.property.imageUrl!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: widget.property.imageUrl!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            memCacheWidth: 120,
                            memCacheHeight: 120,
                            placeholder: (context, url) => Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[900],
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[900],
                              child: const Icon(Icons.home, color: Colors.white),
                            ),
                          ),
                        ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.property.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.property.location,
                              style: TextStyle(color: Colors.grey[400], fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              CountryService.pricePerMonth(widget.property.price),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _launchNavigation,
                          icon: const Icon(Icons.navigation, size: 18),
                          label: Text(AppLocalizations.of(context)!.inAppMapStartNavigation,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      if (widget.property.landlordPhone.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        _MapActionButton(
                          icon: Icons.phone,
                          semanticLabel: AppLocalizations.of(context)!.inAppMapCallLandlord,
                          onTap: _callLandlord,
                          background: AppColors.surfaceContainerHigh,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular icon button (back button, recenter controls): a real
/// Material + InkWell with a guaranteed 44x44 hit target and a
/// Semantics label, instead of a bare GestureDetector + Container --
/// which has no accessible name and no minimum-touch-target guarantee.
/// Mirrors the pattern already used for the favorite button in
/// PropertyCard.
class _MapCircleButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;
  final Color background;
  final Color? borderColor;

  const _MapCircleButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    required this.background,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: background,
        shape: CircleBorder(
          side: borderColor != null ? BorderSide(color: borderColor!) : BorderSide.none,
        ),
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

/// Rounded-square icon button (call), same accessibility rationale as
/// [_MapCircleButton] above but matching the "Start Navigation" button's
/// rounded-rect shape since the two sit side by side in the action row.
class _MapActionButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;
  final Color background;

  const _MapActionButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: background,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(child: Icon(icon, color: Colors.white, size: 20)),
          ),
        ),
      ),
    );
  }
}

/// Covers the map while it's initializing (solid black, so there's no
/// flash of unstyled default-colored tiles before the dark style and
/// markers are ready), or shows a retry option if it never finished
/// within the load timeout. See the timeout fields on
/// _InAppMapPageState for why this exists rather than reacting to a
/// specific SDK error.
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
