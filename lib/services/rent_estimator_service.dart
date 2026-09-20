import 'package:flutter/material.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/theme/app_colors.dart';

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
  final String rating;
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
      rating: json['rating'] as String,
      percentile: (json['percentile'] as num).toDouble(),
      comparableCount: json['comparableCount'] as int,
      valueDrivers: (json['valueDrivers'] as List)
          .map((d) => ValueDriver.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }

  String get ratingLabel {
    switch (rating) {
      case 'GREAT_DEAL':
        return 'Great Deal';
      case 'FAIR_PRICE':
        return 'Fair Market Price';
      case 'ABOVE_MARKET':
        return 'Above Average';
      default:
        return 'Unknown';
    }
  }

  String get ratingEmoji {
    switch (rating) {
      case 'GREAT_DEAL':
        return '🔥';
      case 'FAIR_PRICE':
        return '✓';
      case 'ABOVE_MARKET':
        return '📈';
      default:
        return '';
    }
  }

  /// Monochrome throughout -- previously green/blue/amber, a purely
  /// decorative distinction the rating label and emoji already carry.
  /// The gauge widget conveys position via the needle/marker itself,
  /// not color, matching every other trust/status indicator in the app.
  Color get ratingColor {
    switch (rating) {
      case 'GREAT_DEAL':
        return AppColors.white;
      case 'FAIR_PRICE':
        return AppColors.grey300;
      case 'ABOVE_MARKET':
        return AppColors.grey500;
      default:
        return AppColors.grey600;
    }
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
