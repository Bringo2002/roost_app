import 'dart:ui';

import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/theme/app_colors.dart';

/// Market position rating returned by the server's comparable
/// analysis. Using an enum eliminates 4 separate string-switch
/// statements across the widget and service layers.
enum MarketRating {
  greatDeal,
  fairPrice,
  aboveMarket,
  unknown;

  /// Maps the server's SCREAMING_SNAKE key to a typed value.
  static MarketRating fromKey(String key) => switch (key) {
        'GREAT_DEAL' => MarketRating.greatDeal,
        'FAIR_PRICE' => MarketRating.fairPrice,
        'ABOVE_MARKET' => MarketRating.aboveMarket,
        _ => MarketRating.unknown,
      };

  String get label => switch (this) {
        MarketRating.greatDeal => 'Great Deal',
        MarketRating.fairPrice => 'Fair Market Price',
        MarketRating.aboveMarket => 'Above Average',
        MarketRating.unknown => 'Unknown',
      };

  String get emoji => switch (this) {
        MarketRating.greatDeal => '🔥',
        MarketRating.fairPrice => '✓',
        MarketRating.aboveMarket => '📈',
        MarketRating.unknown => '',
      };

  String get subtitle => switch (this) {
        MarketRating.greatDeal => 'This rent is below the area median — strong value for tenants.',
        MarketRating.fairPrice => 'This rent aligns with comparable listings in the neighborhood.',
        MarketRating.aboveMarket => 'This rent is above most comparables — premium positioning.',
        MarketRating.unknown => '',
      };

  /// Monochrome throughout -- the gauge conveys position via the
  /// needle/marker itself, not color, matching every other
  /// trust/status indicator in the app.
  Color get color => switch (this) {
        MarketRating.greatDeal => AppColors.white,
        MarketRating.fairPrice => AppColors.grey300,
        MarketRating.aboveMarket => AppColors.grey500,
        MarketRating.unknown => AppColors.grey600,
      };
}

class ValueDriver {
  final String label;
  final String impact;
  final bool isPositive;

  const ValueDriver({
    required this.label,
    required this.impact,
    required this.isPositive,
  });

  factory ValueDriver.fromJson(Map<String, dynamic> json) {
    return ValueDriver(
      label: json['label'] as String,
      impact: json['impact'] as String,
      isPositive: json['isPositive'] as bool,
    );
  }
}

class RentEstimate {
  final double minPrice;
  final double medianPrice;
  final double maxPrice;
  final MarketRating rating;
  final double percentile;
  final List<ValueDriver> valueDrivers;
  final int comparableCount;

  const RentEstimate({
    required this.minPrice,
    required this.medianPrice,
    required this.maxPrice,
    required this.rating,
    required this.percentile,
    required this.valueDrivers,
    required this.comparableCount,
  });

  factory RentEstimate.fromJson(Map<String, dynamic> json) {
    return RentEstimate(
      minPrice: (json['minPrice'] as num).toDouble(),
      medianPrice: (json['medianPrice'] as num).toDouble(),
      maxPrice: (json['maxPrice'] as num).toDouble(),
      rating: MarketRating.fromKey(json['rating'] as String),
      percentile: (json['percentile'] as num).toDouble(),
      comparableCount: json['comparableCount'] as int,
      valueDrivers: (json['valueDrivers'] as List)
          .map((d) => ValueDriver.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Thin client for the server-side rent estimate.
///
/// Previously this fetched up to 50 full property records
/// (`/api/properties/filter?type=X&size=50`) on every single
/// detail-page view and recomputed percentiles and value-drivers
/// on-device -- a real bandwidth/latency cost, using its own
/// independent comparable-matching (house type + first word of
/// location, no bedroom filter at all) that could disagree with
/// PropertyRiskService's separate "is this price fair?" feature for
/// the exact same listing. See RentEstimateService.java on the backend
/// for the replacement: one comparable-matching definition (house type
/// + bedrooms + GPS distance, falling back to location text), computed
/// once server-side, returned as a handful of numbers.
class RentEstimatorService {
  static Future<RentEstimate?> estimate(Property property) async {
    final id = property.id;
    if (id == null) return null;

    try {
      final response = await ApiService.get('/api/properties/$id/rent-estimate');
      final json = response as Map<String, dynamic>;
      if (json['available'] != true) return null;
      return RentEstimate.fromJson(json);
    } catch (_) {
      return null; // Graceful failure -- the card just doesn't render.
    }
  }
}
