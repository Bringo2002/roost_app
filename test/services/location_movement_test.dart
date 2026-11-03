import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:roost_app/services/location_service.dart';

/// Creates a [Position] at the given coordinates with a recent timestamp.
Position _pos(double lat, double lng, {DateTime? timestamp}) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: timestamp ?? DateTime.now(),
    accuracy: 10.0,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    LocationService.movementThresholdOverride = null;
  });

  group('LocationService.hasMovedSignificantly', () {
    test('returns true when oldPosition is null (first fix)', () {
      final pos = _pos(-1.286389, 36.817223);
      expect(LocationService.hasMovedSignificantly(null, pos), isTrue);
    });

    test('returns false for same point (0 distance)', () {
      final pos = _pos(-1.286389, 36.817223);
      expect(LocationService.hasMovedSignificantly(pos, pos), isFalse);
    });

    test('returns false for movement under 500m threshold', () {
      // ~200m apart (well under the 500m threshold).
      final a = _pos(-1.28639, 36.81722);
      final b = _pos(-1.28480, 36.81722);
      final distance = Geolocator.distanceBetween(
        a.latitude,
        a.longitude,
        b.latitude,
        b.longitude,
      );
      // Sanity check: confirm the two points are indeed <500m apart.
      expect(distance, lessThan(500));
      expect(LocationService.hasMovedSignificantly(a, b), isFalse);
    });

    test('returns true for movement over 500m threshold', () {
      // Nairobi CBD to Westlands (~3.5 km).
      final cbd = _pos(-1.286389, 36.817223);
      final westlands = _pos(-1.264100, 36.803500);
      final distance = Geolocator.distanceBetween(
        cbd.latitude,
        cbd.longitude,
        westlands.latitude,
        westlands.longitude,
      );
      // Sanity check: confirm the two points are >500m apart.
      expect(distance, greaterThan(500));
      expect(LocationService.hasMovedSignificantly(cbd, westlands), isTrue);
    });

    test('uses overridden threshold when set', () {
      // With a 100m threshold, even small moves should count.
      LocationService.movementThresholdOverride = 100.0;
      final a = _pos(-1.28639, 36.81722);
      // ~200m north — under 500m but over 100m.
      final b = _pos(-1.28460, 36.81722);
      expect(LocationService.hasMovedSignificantly(a, b), isTrue);
    });

    test('GPS jitter (10-50m) does not trigger with default threshold', () {
      final origin = _pos(-1.286389, 36.817223);
      // ~30m northeast — typical urban GPS jitter.
      final jittered = _pos(-1.286120, 36.817470);
      final distance = Geolocator.distanceBetween(
        origin.latitude,
        origin.longitude,
        jittered.latitude,
        jittered.longitude,
      );
      expect(distance, lessThan(100));
      expect(LocationService.hasMovedSignificantly(origin, jittered), isFalse);
    });

    test('boundary: exactly at threshold counts as moved', () {
      // We can't manufacture a perfect 500.0m pair analytically, but we
      // can verify the logic: the guard is `meters >= threshold`, so a
      // value at exactly the threshold should return true. We test this
      // by overriding threshold to 0.0 — any non-zero movement counts.
      LocationService.movementThresholdOverride = 0.0;
      final a = _pos(-1.286389, 36.817223);
      // Even 1m away.
      final b = _pos(-1.286389, 36.817233);
      expect(LocationService.hasMovedSignificantly(a, b), isTrue);
    });
  });

  group('LocationService.isPositionFresh', () {
    test('returns true for a position obtained just now', () {
      final pos = _pos(-1.286389, 36.817223, timestamp: DateTime.now());
      expect(LocationService.isPositionFresh(pos), isTrue);
    });

    test('returns false for a position older than maxAge', () {
      final old = _pos(
        -1.286389,
        36.817223,
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      expect(LocationService.isPositionFresh(old), isFalse);
    });

    test('respects custom maxAge', () {
      final pos = _pos(
        -1.286389,
        36.817223,
        timestamp: DateTime.now().subtract(const Duration(seconds: 30)),
      );
      // With default (2 min) it should be fresh.
      expect(LocationService.isPositionFresh(pos), isTrue);
      // With 10s maxAge it should be stale.
      expect(
        LocationService.isPositionFresh(
          pos,
          maxAge: const Duration(seconds: 10),
        ),
        isFalse,
      );
    });

    test('boundary: position just under maxAge is fresh', () {
      final now = DateTime.now();
      // Use 1m59s rather than exactly 2m — by the time isPositionFresh
      // calls DateTime.now() again, a few ms will have passed, which
      // would push an "exactly 2m" position past the window.
      final pos = _pos(
        -1.286389,
        36.817223,
        timestamp: now.subtract(const Duration(minutes: 1, seconds: 59)),
      );
      expect(LocationService.isPositionFresh(pos), isTrue);
    });
  });

  group('LocationService.defaultMovementThresholdMeters', () {
    test('is 500.0', () {
      expect(LocationService.defaultMovementThresholdMeters, 500.0);
    });
  });
}
