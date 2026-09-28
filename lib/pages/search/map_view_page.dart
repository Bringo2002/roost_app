import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  BitmapDescriptor? _pinIcon;

  @override
  void initState() {
    super.initState();
    _loadPinIcon();
    // Centering on the user happens from onMapCreated, once _mapController
    // actually exists -- calling it here too (as this page previously did)
    // raced two concurrent LocationService.getCurrentPosition() calls,
    // which on some devices means two permission prompts and two GPS
    // reads for the same screen.
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  /// Same monochrome pin used on a single property's own map
  /// (InAppMapPage) -- reused here rather than Google's default marker,
  /// which only ever renders as a red teardrop and was the one thing
  /// breaking this app's strict black/white palette.
  Future<void> _loadPinIcon() async {
    // width/height are passed explicitly: the PNG is 96x120, far too big
    // when many pins share one screen. (BitmapDescriptor.asset honours
    // them; the deprecated fromAssetImage ignored size on mobile.)
    final icon = await BitmapDescriptor.asset(
      const ImageConfiguration(),
      'assets/markers/marker_property.png',
      width: 32,
      height: 40,
    );
    if (!mounted) return;
    setState(() => _pinIcon = icon);
  }

  Future<void> _centerOnUserLocation() async {
    final position = await LocationService.getCurrentPosition();
    if (position == null || !mounted) return;
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude), 13),
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
          // Wait for the pin icon before drawing any markers, same
          // pattern as InAppMapPage -- otherwise every pin briefly
          // flashes as Google's default red teardrop on first frame.
          : _pinIcon == null
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : GoogleMap(
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
                    _centerOnUserLocation();
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  markers: geoProperties.map((p) {
                    return Marker(
                      markerId: MarkerId('property-${p.id}'),
                      position: LatLng(p.latitude!, p.longitude!),
                      infoWindow: InfoWindow(title: p.title, snippet: p.location),
                      icon: _pinIcon!,
                      anchor: const Offset(0.5, 1.0),
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
    );
  }
}
