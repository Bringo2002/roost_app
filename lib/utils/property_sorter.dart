import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/location_service.dart';

/// Pure utility class for sorting properties accurately by proximity,
/// preferences, verified status, and date listed.
class PropertySorter {
  PropertySorter._();

  /// Calculates a secondary preference score (0-27) for ranking ties
  /// or when user location is unknown.
  static int calculatePreferenceScore(
    Property p, {
    String? prefHouseType,
    String? prefBudget,
    String? prefTimeframe,
  }) {
    int score = 0;

    if (prefHouseType != null && prefHouseType != 'ANY' && prefHouseType != 'All') {
      if (p.houseType.toUpperCase() == prefHouseType.toUpperCase()) {
        score += 10;
      }
    }

    if (prefBudget != null) {
      if (prefBudget.contains('Under 15') && p.price < 15000) score += 10;
      if (prefBudget.contains('15k – 30k') && p.price >= 15000 && p.price <= 30000) {
        score += 10;
      }
      if (prefBudget.contains('30k – 60k') && p.price >= 30000 && p.price <= 60000) {
        score += 10;
      }
      if (prefBudget.contains('60,000+') && p.price >= 60000) score += 10;
    }

    if (prefTimeframe == 'Immediately' && p.available) {
      score += 5;
    }

    if (p.verified) score += 2;

    return score;
  }

  /// Calculates distance in km from (userLat, userLng) to property [p].
  /// Returns null if user position or property coordinates are missing.
  static double? distanceKmTo(Property p, double? userLat, double? userLng) {
    final lat = p.latitude;
    final lng = p.longitude;
    if (userLat == null || userLng == null || lat == null || lng == null) {
      return null;
    }
    return LocationService.distanceKm(userLat, userLng, lat, lng);
  }

  /// Sorts a list of properties according to proximity, user preferences,
  /// verified status, and optional newest-first ordering.
  static List<Property> sort(
    List<Property> properties, {
    double? userLat,
    double? userLng,
    String? prefHouseType,
    String? prefBudget,
    String? prefTimeframe,
    bool sortNewestFirst = false,
  }) {
    final list = List<Property>.from(properties);

    list.sort((a, b) {
      // 1. Explicit Newest-First mode
      if (sortNewestFirst) {
        final dateA = DateTime.tryParse(a.listedAt ?? '');
        final dateB = DateTime.tryParse(b.listedAt ?? '');
        if (dateA != null && dateB != null) {
          final cmp = dateB.compareTo(dateA); // newest first
          if (cmp != 0) return cmp;
        } else if (dateA != null) {
          return -1;
        } else if (dateB != null) {
          return 1;
        }
        // Fall through to distance / price tie-breaker
      }

      // 2. Proximity-First mode when user location is available
      final distA = distanceKmTo(a, userLat, userLng);
      final distB = distanceKmTo(b, userLat, userLng);

      if (distA != null && distB != null) {
        // Both properties have valid distance coordinates.
        // Compare distances continuously (closest first).
        final diff = (distA - distB).abs();
        // If distances differ by more than 0.05 km (50 meters), distance strictly wins!
        if (diff > 0.05) {
          return distA.compareTo(distB);
        }
        // Near-tie (< 50 meters apart): break tie using preferences, verification, listed date, price
        final scoreA = calculatePreferenceScore(
          a,
          prefHouseType: prefHouseType,
          prefBudget: prefBudget,
          prefTimeframe: prefTimeframe,
        );
        final scoreB = calculatePreferenceScore(
          b,
          prefHouseType: prefHouseType,
          prefBudget: prefBudget,
          prefTimeframe: prefTimeframe,
        );
        if (scoreA != scoreB) return scoreB.compareTo(scoreA);

        final dateA = DateTime.tryParse(a.listedAt ?? '');
        final dateB = DateTime.tryParse(b.listedAt ?? '');
        if (dateA != null && dateB != null) {
          final cmp = dateB.compareTo(dateA);
          if (cmp != 0) return cmp;
        }

        return a.price.compareTo(b.price);
      } else if (distA != null) {
        // Known coordinates come BEFORE unknown coordinates
        return -1;
      } else if (distB != null) {
        return 1;
      }

      // 3. Fallback when user location is unknown or both properties lack coordinates:
      // Sort by preference score -> verified -> newest -> price
      final scoreA = calculatePreferenceScore(
        a,
        prefHouseType: prefHouseType,
        prefBudget: prefBudget,
        prefTimeframe: prefTimeframe,
      );
      final scoreB = calculatePreferenceScore(
        b,
        prefHouseType: prefHouseType,
        prefBudget: prefBudget,
        prefTimeframe: prefTimeframe,
      );
      if (scoreA != scoreB) return scoreB.compareTo(scoreA);

      final dateA = DateTime.tryParse(a.listedAt ?? '');
      final dateB = DateTime.tryParse(b.listedAt ?? '');
      if (dateA != null && dateB != null) {
        final cmp = dateB.compareTo(dateA);
        if (cmp != 0) return cmp;
      }

      return a.price.compareTo(b.price);
    });

    return list;
  }
}
