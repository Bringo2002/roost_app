import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:roost_app/services/location_service.dart';

Position _position(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 10,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  tearDown(() {
    LocationService.placemarksOverride = null;
    LocationService.cachedNeighborhood = null;
  });

  group('listingAreaFromPlacemark', () {
    test('combines the neighbourhood and the town', () {
      final area = LocationService.listingAreaFromPlacemark(
          Placemark(subLocality: 'Kayole', locality: 'Nairobi'));
      expect(area, 'Kayole, Nairobi');
    });

    test('does not repeat a neighbourhood that is the town', () {
      final area = LocationService.listingAreaFromPlacemark(
          Placemark(subLocality: 'nairobi', locality: 'Nairobi'));
      expect(area, 'nairobi');
    });

    test('falls back to the town when there is no neighbourhood', () {
      final area = LocationService.listingAreaFromPlacemark(
          Placemark(locality: 'Ruaka'));
      expect(area, 'Ruaka');
    });

    test('falls back to the sub-administrative area for the town', () {
      final area = LocationService.listingAreaFromPlacemark(
          Placemark(subLocality: 'Kilimani', subAdministrativeArea: 'Nairobi'));
      expect(area, 'Kilimani, Nairobi');
    });

    test('trims whitespace and treats blanks as missing', () {
      final area = LocationService.listingAreaFromPlacemark(
          Placemark(subLocality: '  Westlands ', locality: '   '));
      expect(area, 'Westlands');
    });

    test('is null when the placemark names no area', () {
      expect(
        LocationService.listingAreaFromPlacemark(
            Placemark(subLocality: '', locality: null)),
        isNull,
      );
    });
  });

  group('listingAreaAt', () {
    test('looks the position up and returns the area', () async {
      double? lat;
      double? lng;
      LocationService.placemarksOverride = (a, b) async {
        lat = a;
        lng = b;
        return [Placemark(subLocality: 'Kayole', locality: 'Nairobi')];
      };

      final area = await LocationService.listingAreaAt(_position(-1.27, 36.91));

      expect(area, 'Kayole, Nairobi');
      expect(lat, -1.27);
      expect(lng, 36.91);
    });

    test('is not cached: a different position gives a different area',
        () async {
      LocationService.cachedNeighborhood = 'Kilimani';
      LocationService.placemarksOverride = (lat, lng) async => [
            lat < -1.3
                ? Placemark(subLocality: 'Karen', locality: 'Nairobi')
                : Placemark(subLocality: 'Kayole', locality: 'Nairobi'),
          ];

      expect(await LocationService.listingAreaAt(_position(-1.27, 36.91)),
          'Kayole, Nairobi');
      expect(await LocationService.listingAreaAt(_position(-1.33, 36.71)),
          'Karen, Nairobi');
    });

    test('is null when the lookup finds nothing', () async {
      LocationService.placemarksOverride = (_, __) async => [];

      expect(await LocationService.listingAreaAt(_position(0, 0)), isNull);
    });

    test('is null, not an error, when the lookup fails', () async {
      LocationService.placemarksOverride =
          (_, __) async => throw Exception('no network');

      expect(await LocationService.listingAreaAt(_position(0, 0)), isNull);
    });
  });
}
