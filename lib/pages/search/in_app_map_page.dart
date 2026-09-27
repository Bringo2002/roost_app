import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:roost_app/config.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/country_service.dart';
import 'package:roost_app/services/location_service.dart';
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
  required bool propertyIconLoaded,
  required Set<String> loadedFacilityIconCategories,
}) {
  final specs = <MapMarkerSpec>[];

  if (propertyIconLoaded) {
    specs.add(MapMarkerSpec(
      id: 'prop_${property.id}',
      latitude: propertyLatLng.latitude,
      longitude: propertyLatLng.longitude,
      title: property.title,
      snippet: property.location,
    ));
  }

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

/// Navigation providers offered by the "Start Navigation" picker sheet.
enum _NavProvider { googleMaps, appleMaps, waze }

class _NavOption {
  final _NavProvider provider;
  final String label;
  final IconData icon;
  const _NavOption(this.provider, this.label, this.icon);
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
  BitmapDescriptor? _propertyIcon;

  @override
  void initState() {
    super.initState();
    final hasCoords = widget.property.latitude != null && widget.property.longitude != null;
    _propertyLatLng = hasCoords
        ? LatLng(widget.property.latitude!, widget.property.longitude!)
        : AppConfig.defaultMapCenter;
    _getUserLocationAndDistance();
    _loadMarkerIcons();
  }

  /// Custom monochrome pins for the property itself and for nearby
  /// facilities (mall/hospital/road) -- these are markers the app itself
  /// places, unlike the base map tiles' own POI icons, so they follow the
  /// strict black/white brand rather than Google's native multi-color
  /// icon glyphs (or, for the property pin, the default red teardrop).
  Future<void> _loadMarkerIcons() async {
    const facilityConfig = ImageConfiguration(size: Size(36, 36));
    const propertyConfig = ImageConfiguration(size: Size(40, 50));
    final results = await Future.wait([
      BitmapDescriptor.fromAssetImage(facilityConfig, 'assets/markers/marker_mall.png'),
      BitmapDescriptor.fromAssetImage(facilityConfig, 'assets/markers/marker_hospital.png'),
      BitmapDescriptor.fromAssetImage(facilityConfig, 'assets/markers/marker_road.png'),
      BitmapDescriptor.fromAssetImage(propertyConfig, 'assets/markers/marker_property.png'),
    ]);
    if (!mounted) return;
    setState(() {
      _facilityIcons['mall'] = results[0];
      _facilityIcons['hospital'] = results[1];
      _facilityIcons['road'] = results[2];
      _propertyIcon = results[3];
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

  /// Lets the person choose which navigation app to hand the trip off to,
  /// instead of forcing Google Maps -- a meaningful gap on iOS in
  /// particular, where Apple Maps or Waze are just as likely to be the
  /// person's default. Mirrors the picker-sheet pattern used by Uber/
  /// Airbnb rather than guessing a single provider.
  Future<void> _showNavigationPicker() async {
    final options = <_NavOption>[
      const _NavOption(_NavProvider.googleMaps, 'Google Maps', Icons.map_outlined),
      // Apple Maps is only ever installed on iOS, so there's no point
      // offering it (and failing) on Android or web.
      if (defaultTargetPlatform == TargetPlatform.iOS)
        const _NavOption(_NavProvider.appleMaps, 'Apple Maps', Icons.map_outlined),
      const _NavOption(_NavProvider.waze, 'Waze', Icons.navigation_outlined),
    ];

    final chosen = await showModalBottomSheet<_NavProvider>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Navigate with',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              for (final option in options)
                ListTile(
                  leading: Icon(option.icon, color: Colors.white),
                  title: Text(option.label, style: const TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(sheetContext, option.provider),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (chosen != null) await _launchNavigation(chosen);
  }

  /// Launches turn-by-turn navigation to the property with the chosen
  /// provider's own app if installed, falling back to that provider's
  /// web URL in a browser, and finally to a visible error instead of the
  /// button silently doing nothing if neither launch succeeds.
  Future<void> _launchNavigation(_NavProvider provider) async {
    final lat = _propertyLatLng.latitude;
    final lng = _propertyLatLng.longitude;

    Uri? appUri;
    late final Uri webUri;
    switch (provider) {
      case _NavProvider.googleMaps:
        appUri = Uri.parse('comgooglemaps://?daddr=$lat,$lng&directionsmode=driving');
        webUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
        break;
      case _NavProvider.appleMaps:
        // maps.apple.com is a universal link: iOS hands it to the Apple
        // Maps app directly when installed (which it always is), no
        // separate app-scheme URI needed.
        webUri = Uri.parse('https://maps.apple.com/?daddr=$lat,$lng&dirflg=d');
        break;
      case _NavProvider.waze:
        appUri = Uri.parse('waze://?ll=$lat,$lng&navigate=yes');
        webUri = Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes');
        break;
    }

    try {
      if (appUri != null) {
        final launchedApp = await launchUrl(appUri, mode: LaunchMode.externalNonBrowserApplication);
        if (launchedApp) return;
      }
      final launchedWeb = await launchUrl(webUri, mode: LaunchMode.externalApplication);
      if (!launchedWeb) throw Exception('No app or browser could handle the maps link');
    } catch (_) {
      _showActionError("Couldn't open navigation. Is a maps app installed?");
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
      _showActionError("Couldn't start a call. Check your phone app is set up.");
    }
  }

  void _showActionError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFF2C2C2E)),
    );
  }

  /// Property pin plus one pin per cached nearby facility (mall/hospital/
  /// major road) -- so "600m from TRM Mall" is something you can actually
  /// see on the map relative to the property, not just read as text.
  ///
  /// Both use custom black/white assets rather than Google's default
  /// markers (which only ever render as a colored teardrop) -- the app's
  /// palette is strictly monochrome, so a stock red pin here would be the
  /// one thing on this screen breaking the brand.
  ///
  /// The which-markers-to-show logic itself lives in [buildMarkerSpecs]
  /// (framework-free, unit-tested); this just attaches the loaded
  /// BitmapDescriptor for each spec.
  Set<Marker> _buildMarkers() {
    final specs = buildMarkerSpecs(
      property: widget.property,
      propertyLatLng: _propertyLatLng,
      propertyIconLoaded: _propertyIcon != null,
      loadedFacilityIconCategories: _facilityIcons.keys.toSet(),
    );

    final markers = <Marker>{};
    for (final spec in specs) {
      final isProperty = spec.id.startsWith('prop_');
      final facilityCategory = isProperty ? null : spec.id.split('_')[1];
      final icon = isProperty ? _propertyIcon! : _facilityIcons[facilityCategory]!;
      markers.add(
        Marker(
          markerId: MarkerId(spec.id),
          position: LatLng(spec.latitude, spec.longitude),
          infoWindow: InfoWindow(title: spec.title, snippet: spec.snippet),
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
          GoogleMap(
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

          // ── Header Bar ────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MapCircleButton(
                    icon: Icons.arrow_back,
                    semanticLabel: 'Back',
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
                              ? '${_distanceKm!.toStringAsFixed(1)} km away'
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
                  semanticLabel: 'Center map on property',
                  onTap: _recenterOnProperty,
                  background: Colors.black.withValues(alpha: 0.9),
                  borderColor: Colors.grey[800],
                ),
                const SizedBox(height: 10),
                if (_userPosition != null)
                  _MapCircleButton(
                    icon: Icons.my_location,
                    semanticLabel: 'Center map on your location',
                    onTap: _recenterOnUser,
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
                color: const Color(0xFF1C1C1E),
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
                          child: Image.network(
                            widget.property.imageUrl!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
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
                          onPressed: _showNavigationPicker,
                          icon: const Icon(Icons.navigation, size: 18),
                          label: const Text('Start Navigation', style: TextStyle(fontWeight: FontWeight.bold)),
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
                          semanticLabel: 'Call landlord',
                          onTap: _callLandlord,
                          background: const Color(0xFF2C2C2E),
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
