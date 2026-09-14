import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/favorites_service.dart';
import 'package:roost_app/services/location_service.dart';

/// Owns every piece of mutable state and network call the property detail
/// screen needs. The widget layer only reads state off this controller and
/// calls its methods -- it never talks to [ApiService] / [FavoritesService]
/// / [LocationService] directly.
///
/// This is a deliberately lightweight `ChangeNotifier` (no external state
/// package) so the page can drive it with a single `AnimatedBuilder` /
/// `ListenableBuilder` without adding a new dependency to the app.
class PropertyDetailController extends ChangeNotifier {
  PropertyDetailController({required this.property});

  final Property property;

  bool isFavorite = false;
  bool communityCheckEligible = false;
  bool communityCheckSubmitted = false;
  Position? userPosition;

  /// True while a favorite toggle is in flight, so the UI can ignore
  /// rapid repeat taps instead of racing two requests.
  bool _togglingFavorite = false;

  /// Kicks off every independent startup fetch in parallel. Each one is
  /// individually non-fatal -- a failure just means that piece of the UI
  /// (distance label, verification badges, eligibility prompt) doesn't
  /// appear, rather than blocking the whole page.
  Future<void> init() async {
    unawaited(_incrementViewCount());
    await Future.wait([
      _checkIfFavorite(),
      _loadUserPosition(),
      _checkCommunityCheckEligibility(),
    ]);
  }

  Future<void> _incrementViewCount() async {
    if (property.id == null) return;
    try {
      await ApiService.get('/api/properties/${property.id}/view');
    } catch (_) {
      // Non-critical: view counts are a nice-to-have metric, not
      // something worth surfacing an error for.
    }
  }

  Future<void> _checkIfFavorite() async {
    if (property.id == null) return;
    try {
      final fav = await FavoritesService.isFavorite(property.id!);
      isFavorite = fav;
      notifyListeners();
    } catch (_) {
      // Leave isFavorite at its default (false) if the check fails.
    }
  }

  Future<void> _loadUserPosition() async {
    final position = await LocationService.getCurrentPosition();
    userPosition = position;
    notifyListeners();
  }

  /// Only shows the "did this match?" prompt to tenants who actually
  /// applied to this listing -- the closest concrete signal of genuine
  /// engagement Roost has today (no scheduled-viewing tracking exists
  /// yet). The backend re-checks this independently on submit; this call
  /// is purely so the UI knows whether to show the prompt at all.
  Future<void> _checkCommunityCheckEligibility() async {
    if (property.id == null) return;
    try {
      final result = await ApiService.get('/api/properties/${property.id}/community-check/eligible');
      communityCheckEligible = result is Map && result['eligible'] == true;
      notifyListeners();
    } catch (_) {
      // Not logged in, or the call failed -- just don't show the prompt.
    }
  }

  Future<void> toggleFavorite() async {
    if (property.id == null || _togglingFavorite) return;
    _togglingFavorite = true;
    // Optimistic flip -- favoriting should feel instant. Rolled back
    // below if the request actually fails.
    isFavorite = !isFavorite;
    notifyListeners();
    try {
      await FavoritesService.toggle(property.id!);
    } catch (_) {
      isFavorite = !isFavorite;
      notifyListeners();
    } finally {
      _togglingFavorite = false;
    }
  }

  /// "450 m away · ~6 min walk" / "3.2 km away · ~8 min drive", or null if
  /// either the user's location or the property's coordinates are unknown.
  String? get distanceLabel {
    final pos = userPosition;
    final lat = property.latitude;
    final lng = property.longitude;
    if (pos == null || lat == null || lng == null) return null;

    final km = LocationService.distanceKm(pos.latitude, pos.longitude, lat, lng);
    final walking = km < 1.5;
    final speedKmh = walking ? 5.0 : 30.0;
    final minutes = (km / speedKmh * 60).round().clamp(1, 999);
    final mode = walking ? 'walk' : 'drive';
    return '${LocationService.formatDistance(km)} · ~$minutes min $mode';
  }

  /// Submits a community check. Throws [ApiException] (or any other
  /// error the request produces) on failure so the sheet can show it --
  /// the controller doesn't touch `BuildContext` or show UI itself.
  Future<void> submitCommunityCheck({
    required bool visited,
    required bool photosAccurate,
    required bool locationAccurate,
    required bool priceAccurate,
    required bool wouldRecommend,
  }) async {
    await ApiService.post('/api/properties/${property.id}/community-check', {
      'visited': visited,
      'photosAccurate': visited && photosAccurate,
      'locationAccurate': visited && locationAccurate,
      'priceAccurate': visited && priceAccurate,
      'wouldRecommend': visited && wouldRecommend,
    });
    communityCheckSubmitted = true;
    notifyListeners();
  }

  /// Throws on failure, same contract as [submitCommunityCheck].
  Future<void> reportProperty(String reason) async {
    await ApiService.post('/api/properties/${property.id}/report', {
      'reason': reason,
    });
  }
}
