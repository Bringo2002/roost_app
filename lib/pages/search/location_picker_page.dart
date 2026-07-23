import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roost_app/services/location_service.dart';

class LocationPickerPage extends StatefulWidget {
  final LatLng initialCenter;

  const LocationPickerPage({
    super.key,
    this.initialCenter = const LatLng(-1.2921, 36.8219), // Nairobi center
  });

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  LatLng? _selectedLocation;
  GoogleMapController? _mapController;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    final position = await LocationService.getCurrentPosition();
    if (position == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't get your current location")),
      );
      return;
    }
    final point = LatLng(position.latitude, position.longitude);
    setState(() => _selectedLocation = point);
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(point, 15));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tap to Pin Location'),
        actions: [
          if (_selectedLocation != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context, _selectedLocation);
              },
              child: const Text('Confirm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: widget.initialCenter, zoom: 13),
            onMapCreated: (controller) => _mapController = controller,
            onTap: (point) => setState(() => _selectedLocation = point),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: _selectedLocation != null
                ? {
                    Marker(
                      markerId: const MarkerId('selected'),
                      position: _selectedLocation!,
                    ),
                  }
                : {},
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              heroTag: 'use-current-location',
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              onPressed: _useCurrentLocation,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
