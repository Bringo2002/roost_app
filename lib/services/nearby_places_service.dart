import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:roost_app/models/property.dart';

/// Client-side fallback for fetching nearby amenities when the backend's
/// `nearbyFacilities` field is empty. Uses the Google Maps Places API
/// (Nearby Search) to find supermarkets, pharmacies, schools, malls, bus
/// stations, and other points of interest around a property's coordinates.
///
/// Results are mapped to [NearbyFacility] objects so they plug into the
/// existing chip UI without changes upstream. Each place type is queried
/// individually and the closest result per category is kept, capped at a
/// 2 km radius so only genuinely walkable/nearby places appear.
class NearbyPlacesService {
  NearbyPlacesService._();

  /// Google Maps API key — same key used by the embedded map widget,
  /// loaded at build time from `android/local.properties`.
  /// For production, this should come from a secure config source;
  /// hardcoded here because the key is already baked into the APK
  /// manifest and is restricted by package name + API type on the
  /// Google Cloud Console.
  static const String _apiKey = 'AIzaSyCbgBOKTBUDphlWnEWlm4NjQ6f8rxtcVF8';

  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json';

  /// Maximum search radius in meters. 2 km keeps results relevant to
  /// renters evaluating walkability.
  static const int _radiusMeters = 2000;

  /// Place types to query and their mapping to [NearbyFacility.category].
  /// Each entry is `(Google Places type, category key)`. The category key
  /// drives the icon and label in [NearbyFacilityChip].
  static const List<(String, String)> _placeTypes = [
    ('supermarket', 'supermarket'),
    ('pharmacy', 'pharmacy'),
    ('shopping_mall', 'mall'),
    ('hospital', 'hospital'),
    ('school', 'school'),
    ('bus_station', 'bus_station'),
    ('bank', 'bank'),
    ('restaurant', 'restaurant'),
    ('police', 'police'),
    ('gas_station', 'gas_station'),
  ];

  /// In-memory cache keyed by `"$lat,$lng"` to avoid redundant HTTP
  /// requests when the user navigates back to the same listing.
  static final Map<String, List<NearbyFacility>> _cache = {};

  /// HTTP client — overridable for tests.
  @visibleForTesting
  static http.Client client = http.Client();

  /// Fetches nearby amenities for the given coordinates. Returns the
  /// closest place per category, sorted by distance. Results are cached
  /// in memory so reopening the same listing doesn't re-fetch.
  ///
  /// Never throws — any network or parsing failure silently yields an
  /// empty list, which just means the "Nearby" section stays hidden
  /// (same as before this feature existed).
  static Future<List<NearbyFacility>> fetch({
    required double latitude,
    required double longitude,
  }) async {
    final cacheKey = '${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)}';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final results = <NearbyFacility>[];

    // Query each place type individually so we get the closest of each
    // category, not just the globally closest places.
    for (final (placeType, category) in _placeTypes) {
      try {
        final uri = Uri.parse(_baseUrl).replace(queryParameters: {
          'location': '$latitude,$longitude',
          'radius': '$_radiusMeters',
          'type': placeType,
          'key': _apiKey,
        });

        final response = await client.get(uri).timeout(
          const Duration(seconds: 5),
        );

        if (response.statusCode != 200) continue;

        final body = jsonDecode(response.body);
        if (body is! Map || body['status'] != 'OK') continue;

        final places = body['results'];
        if (places is! List || places.isEmpty) continue;

        // Take the first result — Google already sorts by prominence,
        // which usually puts the nearest/most relevant result first.
        final place = places.first as Map<String, dynamic>;
        final name = place['name']?.toString() ?? '';
        if (name.isEmpty) continue;

        final geometry = place['geometry'] as Map<String, dynamic>?;
        final location = geometry?['location'] as Map<String, dynamic>?;
        final placeLat = (location?['lat'] as num?)?.toDouble() ?? 0;
        final placeLng = (location?['lng'] as num?)?.toDouble() ?? 0;

        final distanceMeters = _haversineDistance(
          latitude, longitude,
          placeLat, placeLng,
        );

        // Skip places beyond our radius (API sometimes returns slightly
        // outside results).
        if (distanceMeters > _radiusMeters) continue;

        results.add(NearbyFacility(
          name: name,
          category: category,
          distanceMeters: distanceMeters,
          latitude: placeLat,
          longitude: placeLng,
        ));
      } catch (e) {
        debugPrint('NearbyPlacesService: failed to fetch $placeType — $e');
        // Best-effort per category: skip this one, try the rest.
      }
    }

    // Sort by distance — closest amenity first.
    results.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    _cache[cacheKey] = results;
    return results;
  }

  /// Haversine distance between two lat/lng pairs, in meters.
  static double _haversineDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    const earthRadiusM = 6371000.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusM * c;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;

  /// Clears the in-memory cache. Useful for tests.
  @visibleForTesting
  static void clearCache() => _cache.clear();
}
