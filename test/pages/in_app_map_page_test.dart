import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/pages/search/in_app_map_page.dart';

Property _property({List<NearbyFacility> nearbyFacilities = const []}) {
  final base = Property.fromJson({
    'id': 42,
    'title': 'Sunny Studio',
    'description': 'A nice place',
    'location': 'Kilimani, Nairobi',
    'price': 30000.0,
    'bedrooms': 1,
    'type': 'RENTAL',
    'houseType': 'STUDIO',
    'landlordPhone': '+254700000000',
    'available': true,
    'lat': -1.2921,
    'lng': 36.8219,
    'verified': false,
    'listedAt': '2026-01-01T10:00:00Z',
  });
  return base.copyWith(nearbyFacilities: nearbyFacilities);
}

const _propertyLatLng = LatLng(-1.2921, 36.8219);

void main() {
  group('buildMarkerSpecs', () {
    test('omits the property marker until its icon has loaded', () {
      final specs = buildMarkerSpecs(
        property: _property(),
        propertyLatLng: _propertyLatLng,
        propertyIconLoaded: false,
        loadedFacilityIconCategories: {},
      );
      expect(specs, isEmpty);
    });

    test('includes the property marker with its id/title/snippet once loaded', () {
      final specs = buildMarkerSpecs(
        property: _property(),
        propertyLatLng: _propertyLatLng,
        propertyIconLoaded: true,
        loadedFacilityIconCategories: {},
      );
      expect(specs, hasLength(1));
      expect(specs.single.id, 'prop_42');
      expect(specs.single.title, 'Sunny Studio');
      expect(specs.single.snippet, 'Kilimani, Nairobi');
      expect(specs.single.latitude, _propertyLatLng.latitude);
      expect(specs.single.longitude, _propertyLatLng.longitude);
    });

    test('skips a facility whose category icon has not loaded yet, keeps the rest', () {
      final facilities = [
        const NearbyFacility(name: 'TRM Mall', category: 'mall', distanceMeters: 600, latitude: -1.29, longitude: 36.88),
        const NearbyFacility(name: 'Aga Khan Hospital', category: 'hospital', distanceMeters: 1200, latitude: -1.27, longitude: 36.81),
      ];
      final specs = buildMarkerSpecs(
        property: _property(nearbyFacilities: facilities),
        propertyLatLng: _propertyLatLng,
        propertyIconLoaded: true,
        loadedFacilityIconCategories: {'mall'}, // hospital icon "still loading"
      );

      final ids = specs.map((s) => s.id).toSet();
      expect(ids, contains('prop_42'));
      expect(ids, contains('facility_mall_TRM Mall'));
      expect(ids.any((id) => id.contains('hospital')), isFalse);
      expect(specs, hasLength(2));
    });

    test('facility snippet matches NearbyFacility.label (e.g. "600m from TRM Mall")', () {
      final facilities = [
        const NearbyFacility(name: 'TRM Mall', category: 'mall', distanceMeters: 600, latitude: -1.29, longitude: 36.88),
      ];
      final specs = buildMarkerSpecs(
        property: _property(nearbyFacilities: facilities),
        propertyLatLng: _propertyLatLng,
        propertyIconLoaded: false, // isolate the facility marker
        loadedFacilityIconCategories: {'mall'},
      );
      expect(specs, hasLength(1));
      expect(specs.single.snippet, '600m from TRM Mall');
    });

    test('with everything loaded, returns one marker per facility plus the property', () {
      final facilities = [
        const NearbyFacility(name: 'TRM Mall', category: 'mall', distanceMeters: 600, latitude: -1.29, longitude: 36.88),
        const NearbyFacility(name: 'Aga Khan Hospital', category: 'hospital', distanceMeters: 1200, latitude: -1.27, longitude: 36.81),
        const NearbyFacility(name: 'Thika Superhighway', category: 'road', distanceMeters: 300, latitude: -1.28, longitude: 36.83),
      ];
      final specs = buildMarkerSpecs(
        property: _property(nearbyFacilities: facilities),
        propertyLatLng: _propertyLatLng,
        propertyIconLoaded: true,
        loadedFacilityIconCategories: {'mall', 'hospital', 'road'},
      );
      expect(specs, hasLength(4));
    });
  });
}
