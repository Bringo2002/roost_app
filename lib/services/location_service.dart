import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Why [LocationService.checkPermissionStatus] can't currently give the
/// device's position -- or that it can. Separate from
/// [LocationService.getCurrentPosition], which deliberately collapses
/// every failure into `null` for callers that just want a best-effort
/// position; this is for the minority of callers (the map screens) that
/// need to tell "nothing we can do here" apart from "the user could fix
/// this, and here's how" so they can show the right prompt instead of a
/// feature that silently never works.
enum LocationPermissionStatus {
  /// Location services are off at the OS level (not an app permission).
  /// Fixable via [LocationService.openLocationSettings].
  serviceDisabled,

  /// Permission was never granted, or was denied but can still be
  /// re-requested in-app (no OS-level "don't ask again").
  denied,

  /// Permission was denied with "don't ask again" (Android) or is
  /// otherwise permanently refused (iOS). Only fixable by the user
  /// visiting the app's OS settings -- requesting again in-app is a
  /// silent no-op at this point.
  deniedForever,

  /// Permission is granted; a `null` from [LocationService.getCurrentPosition]
  /// despite this means a transient failure (GPS timeout, etc.), not
  /// something a settings prompt would fix.
  granted,
}

/// Wraps device geolocation for "properties near me" features. Never
/// throws -- every method degrades gracefully (returns null / doesn't
/// sort) if location services are off or permission is denied, since
/// location is an enhancement here, not something that should block
/// browsing properties.
class LocationService {
  LocationService._();

  static String? cachedNeighborhood;

  // ── Movement threshold ────────────────────────────────────────────

  /// Minimum distance (in meters) a user must move before the feed
  /// considers the location "meaningfully changed" and triggers a
  /// re-fetch. Set to 500 m because:
  ///
  /// * Nairobi neighborhoods (Kilimani, Westlands, Ruaka) are typically
  ///   1–3 km apart — 500 m likely means a cross-neighborhood move.
  /// * Urban GPS jitter is typically 10–50 m with medium accuracy;
  ///   500 m is well above that noise floor.
  /// * Property listings are relevant at neighborhood scale, not
  ///   building-by-building — a 500 m move doesn't change which
  ///   listings are nearby in any meaningful way.
  static const double defaultMovementThresholdMeters = 500.0;

  /// Override for tests. Reset in `tearDown`.
  @visibleForTesting
  static double? movementThresholdOverride;

  /// The active movement threshold in meters.
  static double get _movementThreshold =>
      movementThresholdOverride ?? defaultMovementThresholdMeters;

  /// Returns `true` if [newPosition] is far enough from [oldPosition]
  /// to count as a meaningful location change (exceeds the movement
  /// threshold). Always returns `true` when [oldPosition] is null
  /// (first fix).
  static bool hasMovedSignificantly(
    Position? oldPosition,
    Position newPosition,
  ) {
    if (oldPosition == null) return true;
    final meters = Geolocator.distanceBetween(
      oldPosition.latitude,
      oldPosition.longitude,
      newPosition.latitude,
      newPosition.longitude,
    );
    return meters >= _movementThreshold;
  }

  /// Whether [position] was obtained recently enough to skip a new GPS
  /// fix. Default staleness window is 2 minutes — long enough that a
  /// fresh fix from 30 seconds ago isn't wasted, short enough that a
  /// user who put the phone down for 5 minutes gets a re-check.
  static bool isPositionFresh(
    Position position, {
    Duration maxAge = const Duration(minutes: 2),
  }) {
    final age = DateTime.now().difference(position.timestamp);
    return age <= maxAge;
  }

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

  /// Test seam for [getCurrentPosition]: when set, it replaces the
  /// Geolocator calls entirely so widget tests can supply a fixed position
  /// (or `null`) without platform channels. Reset to `null` in `tearDown`
  /// so one test's override can't leak into the next.
  @visibleForTesting
  static Future<Position?> Function()? getCurrentPositionOverride;

  /// Returns the device's current position, or null if location services
  /// are disabled, permission is denied, or anything else goes wrong.
  static Future<Position?> getCurrentPosition() {
    final override = getCurrentPositionOverride;
    if (override != null) return override();
    return _getCurrentPositionFromDevice();
  }

  static Future<Position?> _getCurrentPositionFromDevice() async {
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

  /// Tells a caller *why* [getCurrentPosition] would return null right
  /// now, without actually requesting a GPS fix -- for UI that wants to
  /// show "enable location" rather than just quietly doing nothing. Does
  /// not prompt for permission itself (unlike [getCurrentPosition]); call
  /// this to decide what to show, then re-call [getCurrentPosition] if
  /// the user chooses to proceed.
  static Future<LocationPermissionStatus> checkPermissionStatus() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationPermissionStatus.serviceDisabled;
      }
      switch (await Geolocator.checkPermission()) {
        case LocationPermission.denied:
          return LocationPermissionStatus.denied;
        case LocationPermission.deniedForever:
          return LocationPermissionStatus.deniedForever;
        case LocationPermission.whileInUse:
        case LocationPermission.always:
        case LocationPermission.unableToDetermine:
          return LocationPermissionStatus.granted;
      }
    } catch (_) {
      // Unable to even check -- nothing a settings prompt can promise to
      // fix, so don't claim otherwise.
      return LocationPermissionStatus.granted;
    }
  }

  /// Opens the device's location-services toggle (not the app's own
  /// settings page) -- for [LocationPermissionStatus.serviceDisabled].
  static Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  /// Opens this app's OS settings page -- for
  /// [LocationPermissionStatus.deniedForever], where re-requesting
  /// permission in-app is a silent no-op and the OS requires the user to
  /// grant it from Settings instead.
  static Future<void> openAppSettings() => Geolocator.openAppSettings();

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
