import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/country_service.dart';
import 'package:roost_app/services/location_service.dart';
import 'package:roost_app/theme/app_map_style.dart';

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

  @override
  void initState() {
    super.initState();
    final lat = widget.property.latitude ?? -1.2921;
    final lng = widget.property.longitude ?? 36.8219;
    _propertyLatLng = LatLng(lat, lng);
    _getUserLocationAndDistance();
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

  /// Launches Google Maps directly for navigation — no app chooser.
  /// Uses explicit Google Maps package URL to bypass Uber / other nav apps.
  Future<void> _launchGoogleMapsNavigation() async {
    final lat = _propertyLatLng.latitude;
    final lng = _propertyLatLng.longitude;

    // Google Maps-specific URL that opens directly in Google Maps app
    final mapsUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );

    try {
      // Launch with externalNonBrowserApplication to target Google Maps app directly
      await launchUrl(mapsUri, mode: LaunchMode.externalNonBrowserApplication);
    } catch (_) {
      // Fallback: open in any browser/app
      await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
    }
  }

  void _callLandlord() async {
    final phone = widget.property.landlordPhone;
    if (phone.isNotEmpty) {
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
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
            onMapCreated: (controller) {
              _mapController = controller;
            },
            markers: {
              Marker(
                markerId: MarkerId('prop_${widget.property.id}'),
                position: _propertyLatLng,
                infoWindow: InfoWindow(
                  title: widget.property.title,
                  snippet: widget.property.location,
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              ),
            },
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
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                    ),
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
                GestureDetector(
                  onTap: _recenterOnProperty,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey[800]!),
                    ),
                    child: const Icon(Icons.home_work_outlined, color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(height: 10),
                if (_userPosition != null)
                  GestureDetector(
                    onTap: _recenterOnUser,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey[800]!),
                      ),
                      child: const Icon(Icons.my_location, color: Colors.white, size: 22),
                    ),
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
                          onPressed: _launchGoogleMapsNavigation,
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
                        GestureDetector(
                          onTap: _callLandlord,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C2C2E),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.phone, color: Colors.white, size: 20),
                          ),
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
