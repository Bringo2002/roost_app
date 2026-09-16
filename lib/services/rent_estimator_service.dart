import 'package:flutter/material.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/api_service.dart';

class ValueDriver {
  final String label;
  final String impact;
  final bool isPositive;

  const ValueDriver({
    required this.label,
    required this.impact,
    required this.isPositive,
  });
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

  Color get ratingColor {
    switch (rating) {
      case 'GREAT_DEAL':
        return const Color(0xFF10B981);
      case 'FAIR_PRICE':
        return const Color(0xFF38BDF8);
      case 'ABOVE_MARKET':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }
}

class RentEstimatorService {
  static Future<RentEstimate?> estimate(Property property) async {
    try {
      final response = await ApiService.get('/api/properties/filter?type=${property.houseType}&size=50');
      if (response == null) return null;

      final List<dynamic> data = response;
      final List<Property> allComps = data.map((json) => Property.fromJson(json)).toList();

      if (allComps.isEmpty) return null;

      final propertyLocationFirstWord = property.location.split(' ').first.toLowerCase();
      
      List<Property> locationComps = allComps.where((p) {
        final compFirstWord = p.location.split(' ').first.toLowerCase();
        return compFirstWord == propertyLocationFirstWord;
      }).toList();

      List<Property> compsToUse = locationComps.length >= 3 ? locationComps : allComps;

      if (compsToUse.length < 3) return null;

      List<double> prices = compsToUse.map((p) => p.price.toDouble()).toList()..sort();

      double minPrice = _percentile(prices, 0.25);
      double medianPrice = _percentile(prices, 0.50);
      double maxPrice = _percentile(prices, 0.75);

      String rating;
      if (property.price <= medianPrice) {
        rating = 'GREAT_DEAL';
      } else if (property.price <= maxPrice) {
        rating = 'FAIR_PRICE';
      } else {
        rating = 'ABOVE_MARKET';
      }

      int lowerOrEqualCount = prices.where((p) => p <= property.price).length;
      double percentile = lowerOrEqualCount / prices.length;

      List<ValueDriver> valueDrivers = _analyzeValueDrivers(property, compsToUse);

      return RentEstimate(
        minPrice: minPrice,
        medianPrice: medianPrice,
        maxPrice: maxPrice,
        rating: rating,
        percentile: percentile,
        valueDrivers: valueDrivers,
        comparableCount: compsToUse.length,
      );
    } catch (e) {
      return null; // Graceful failure
    }
  }

  static double _percentile(List<double> sorted, double p) {
    if (sorted.isEmpty) return 0.0;
    if (sorted.length == 1) return sorted.first;
    if (p <= 0) return sorted.first;
    if (p >= 1) return sorted.last;

    final position = p * (sorted.length - 1);
    final index = position.floor();
    final fraction = position - index;

    return sorted[index] + fraction * (sorted[index + 1] - sorted[index]);
  }

  static List<ValueDriver> _analyzeValueDrivers(Property property, List<Property> comps) {
    List<Map<String, dynamic>> driverData = [];
    int total = comps.length;
    if (total == 0) return [];

    void processAmenity(bool hasAmenity, String label, bool Function(Property) compHas) {
      int count = comps.where(compHas).length;
      double prevalence = count / total;

      if (hasAmenity) {
        if (prevalence < 0.50) {
          String impact;
          if (prevalence < 0.10) {
            impact = '+10-15%';
          } else if (prevalence < 0.25) {
            impact = '+5-10%';
          } else {
            impact = '+3-5%';
          }
          driverData.add({
            'driver': ValueDriver(label: label, impact: impact, isPositive: true),
            'prevalence': prevalence,
          });
        }
      } else {
        if (prevalence > 0.70) {
          driverData.add({
            'driver': ValueDriver(label: 'Missing $label', impact: '-5-8%', isPositive: false),
            'prevalence': prevalence,
          });
        }
      }
    }

    processAmenity(property.parking, 'Dedicated Parking', (p) => p.parking);
    processAmenity(property.furnished, 'Fully Furnished', (p) => p.furnished);
    processAmenity(property.wifi, 'WiFi Included', (p) => p.wifi);
    processAmenity(property.generator, 'Backup Generator', (p) => p.generator);
    processAmenity(property.pool, 'Swimming Pool', (p) => p.pool);
    processAmenity(property.gym, 'Gym Access', (p) => p.gym);
    processAmenity(property.elevator, 'Elevator Access', (p) => p.elevator);
    processAmenity(property.balcony, 'Private Balcony', (p) => p.balcony);
    processAmenity(property.security, '24/7 Security', (p) => p.security);
    processAmenity(property.solar, 'Solar Power', (p) => p.solar);

    driverData.sort((a, b) {
      bool aPos = (a['driver'] as ValueDriver).isPositive;
      bool bPos = (b['driver'] as ValueDriver).isPositive;

      if (aPos && bPos) {
        return (a['prevalence'] as double).compareTo(b['prevalence'] as double);
      } else if (!aPos && !bPos) {
        return (b['prevalence'] as double).compareTo(a['prevalence'] as double);
      } else {
        return aPos ? -1 : 1;
      }
    });

    List<ValueDriver> finalDrivers = driverData.map((d) => d['driver'] as ValueDriver).toList();

    if (finalDrivers.length > 5) {
      return finalDrivers.sublist(0, 5);
    }
    return finalDrivers;
  }
}
