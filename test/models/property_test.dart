import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/models/property.dart';

void main() {
  group('Property Utility Breakdown & JSON Tests', () {
    test('parses camelCase utility fields correctly', () {
      final json = {
        'title': 'Luxury Studio',
        'description': 'Cozy apartment',
        'location': 'Kilmimani, Nairobi',
        'price': 45000.0,
        'bedrooms': 1,
        'type': 'RENTAL',
        'landlordPhone': '+254712345678',
        'available': true,
        'waterFee': 1500.0,
        'garbageFee': 500.0,
        'serviceCharge': 2500.0,
        'depositMonths': 2,
        'electricityType': 'tokens',
      };

      final property = Property.fromJson(json);

      expect(property.waterFee, equals(1500.0));
      expect(property.garbageFee, equals(500.0));
      expect(property.serviceCharge, equals(2500.0));
      expect(property.depositMonths, equals(2));
      expect(property.electricityType, equals('tokens'));
      expect(property.totalMonthlyUtilityCost, equals(45000 + 1500 + 500 + 2500));
      expect(property.totalInitialMoveInCost, equals(45000 + (45000 * 2) + 1500 + 500 + 2500));
    });

    test('parses snake_case utility fields from backend API', () {
      final json = {
        'title': 'Modern 2BR',
        'description': 'Spacious unit',
        'location': 'Westlands, Nairobi',
        'price': 75000.0,
        'bedrooms': 2,
        'type': 'RENTAL',
        'landlordPhone': '+254712345678',
        'available': true,
        'water_fee': 2000.0,
        'garbage_fee': 600.0,
        'service_charge': 3500.0,
        'deposit_months': 1,
        'electricity_type': 'postpaid',
      };

      final property = Property.fromJson(json);

      expect(property.waterFee, equals(2000.0));
      expect(property.garbageFee, equals(600.0));
      expect(property.serviceCharge, equals(3500.0));
      expect(property.depositMonths, equals(1));
      expect(property.electricityType, equals('postpaid'));
    });

    test('parses numeric string values safely (with commas and decimals)', () {
      final json = {
        'title': 'Bedsitter',
        'description': 'Affordable',
        'location': 'Ruiru',
        'price': '15,000',
        'bedrooms': '1',
        'type': 'RENTAL',
        'landlordPhone': '+254700000000',
        'available': true,
        'waterFee': '1,200.50',
        'garbageFee': '300',
        'serviceCharge': '1,000',
        'depositMonths': '1',
        'electricityType': 'included',
      };

      final property = Property.fromJson(json);

      expect(property.price, equals(15000.0));
      expect(property.waterFee, equals(1200.50));
      expect(property.garbageFee, equals(300.0));
      expect(property.serviceCharge, equals(1000.0));
      expect(property.depositMonths, equals(1));
      expect(property.electricityType, equals('included'));
    });

    test('toJson serializes both camelCase and snake_case keys for API compatibility', () {
      final property = Property(
        title: 'Penthouse',
        description: 'Luxury',
        location: 'Lavington',
        price: 120000.0,
        bedrooms: 3,
        type: 'RENTAL',
        landlordPhone: '+254722000111',
        available: true,
        waterFee: 3000.0,
        garbageFee: 800.0,
        serviceCharge: 5000.0,
        depositMonths: 2,
        electricityType: 'postpaid',
      );

      final json = property.toJson();

      expect(json['waterFee'], equals(3000.0));
      expect(json['water_fee'], equals(3000.0));
      expect(json['garbageFee'], equals(800.0));
      expect(json['garbage_fee'], equals(800.0));
      expect(json['serviceCharge'], equals(5000.0));
      expect(json['service_charge'], equals(5000.0));
      expect(json['depositMonths'], equals(2));
      expect(json['deposit_months'], equals(2));
      expect(json['electricityType'], equals('postpaid'));
      expect(json['electricity_type'], equals('postpaid'));
    });
  });
}
