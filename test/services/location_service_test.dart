import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/services/location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocationService.distanceKm', () {
    test('is ~0 for the same point', () {
      final km = LocationService.distanceKm(-1.286389, 36.817223, -1.286389, 36.817223);
      expect(km, closeTo(0, 0.001));
    });

    test('matches the known Nairobi CBD -> JKIA distance (~15-17 km)', () {
      // Nairobi CBD to Jomo Kenyatta International Airport.
      final km = LocationService.distanceKm(-1.286389, 36.817223, -1.319167, 36.927222);
      expect(km, greaterThan(10));
      expect(km, lessThan(20));
    });

    test('is symmetric', () {
      const aLat = -1.2921, aLng = 36.8219;
      const bLat = -1.3031, bLng = 36.7073;
      final ab = LocationService.distanceKm(aLat, aLng, bLat, bLng);
      final ba = LocationService.distanceKm(bLat, bLng, aLat, aLng);
      expect(ab, closeTo(ba, 0.0001));
    });
  });

  group('LocationService.formatDistance', () {
    test('renders sub-km distances in meters', () {
      expect(LocationService.formatDistance(0.45), '450 m away');
      expect(LocationService.formatDistance(0.005), '5 m away');
    });

    test('renders 1-10 km with one decimal place', () {
      expect(LocationService.formatDistance(1.0), '1.0 km away');
      expect(LocationService.formatDistance(3.24), '3.2 km away');
      expect(LocationService.formatDistance(9.99), '10.0 km away');
    });

    test('renders 10+ km rounded to a whole number', () {
      expect(LocationService.formatDistance(10.0), '10 km away');
      expect(LocationService.formatDistance(12.6), '13 km away');
    });

    test('boundary just under 1 km stays in meters, not "1.0 km"', () {
      // 0.999 km = 999 m: should round to meters, not slip into the
      // km branch and print "1.0 km away" for something under a km.
      expect(LocationService.formatDistance(0.999), '999 m away');
    });
  });

  group('LocationService graceful degradation (no platform available in unit tests)', () {
    // These calls hit Geolocator/geocoding platform channels that have no
    // mock handler registered in a plain `flutter test` run, which is
    // exactly the same failure shape as "permission denied" or "location
    // services off" on a real device: the plugin call fails. LocationService
    // promises it never throws and always degrades to null -- this
    // exercises that contract for real, rather than asserting it.
    setUp(() {
      LocationService.cachedNeighborhood = null;
    });

    test('getCurrentPosition() resolves to null instead of throwing', () async {
      expect(await LocationService.getCurrentPosition(), isNull);
    });

    test('getNeighborhoodName() resolves to null instead of throwing', () async {
      expect(await LocationService.getNeighborhoodName(), isNull);
    });

    test('getNeighborhoodName() returns the cached value without touching the platform', () async {
      LocationService.cachedNeighborhood = 'Kilimani';
      expect(await LocationService.getNeighborhoodName(), 'Kilimani');
    });

    test('checkPermissionStatus() resolves to granted (its safe fallback) instead of throwing', () async {
      // isLocationServiceEnabled() throws here for the same reason
      // getCurrentPosition() does above; the method deliberately treats
      // "can't even check" the same as "granted" -- not claiming a
      // settings prompt would help when it has no idea whether one would.
      expect(await LocationService.checkPermissionStatus(), LocationPermissionStatus.granted);
    });
  });
}
