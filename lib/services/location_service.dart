import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Wraps device geolocation for "properties near me" features. Never
/// throws -- every method degrades gracefully (returns null / doesn't
/// sort) if location services are off or permission is denied, since
/// location is an enhancement here, not something that should block
/// browsing properties.
class LocationService {
  LocationService._();

  static String? cachedNeighborhood;

  /// Attempts to reverse geocode [position] or current device location to get
  /// a human-readable neighborhood/locality name (e.g. "Kilimani", "Westlands", "Ruaka").
  static Future<String?> getNeighborhoodName([Position? position]) async {
    if (cachedNeighborhood != null && cachedNeighborhood!.isNotEmpty) {
      return cachedNeighborhood;
    }
    try {
      final pos = position ?? await getCurrentPosition();
      if (pos == null) return null;

      final placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      ).timeout(const Duration(seconds: 4));

      if (placemarks.isEmpty) return null;

      final place = placemarks.first;
      final name = (place.subLocality != null && place.subLocality!.trim().isNotEmpty)
          ? place.subLocality!.trim()
          : ((place.locality != null && place.locality!.trim().isNotEmpty)
              ? place.locality!.trim()
              : place.subAdministrativeArea?.trim());

      if (name != null && name.isNotEmpty) {
        cachedNeighborhood = name;
        return name;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Returns the device's current position, or null if location services
  /// are disabled, permission is denied, or anything else goes wrong.
  static Future<Position?> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
    } catch (_) {
      return null;
    }
  }

  /// Straight-line distance in kilometers between two coordinates.
  static double distanceKm(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }

  /// Human-readable distance label, e.g. "450 m away" or "3.2 km away".
  static String formatDistance(double km) {
    if (km < 1) return '${(km * 1000).round()} m away';
    if (km < 10) return '${km.toStringAsFixed(1)} km away';
    return '${km.round()} km away';
  }
}
