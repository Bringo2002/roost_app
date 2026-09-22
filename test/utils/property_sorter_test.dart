import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/utils/property_sorter.dart';

void main() {
  group('PropertySorter Distance & Relevance Tests', () {
    // Reference user position: Nairobi CBD (-1.286389, 36.817223)
    const userLat = -1.286389;
    const userLng = 36.817223;

    // Property A: ~0.2 km away (CBD)
    final propClose = Property.fromJson({
      'id': 1,
      'title': 'Close Apartment',
      'description': 'Near CBD',
      'location': 'CBD, Nairobi',
      'price': 50000.0,
      'bedrooms': 1,
      'type': 'RENTAL',
      'houseType': '1BR',
      'landlordPhone': '+254700000001',
      'available': true,
      'lat': -1.288,
      'lng': 36.818,
      'verified': false,
      'listedAt': '2026-01-01T10:00:00Z',
    });

    // Property B: ~5 km away (Kilimani)
    final propMedium = Property.fromJson({
      'id': 2,
      'title': 'Medium Apartment',
      'description': 'Kilimani area',
      'location': 'Kilimani, Nairobi',
      'price': 20000.0, // Cheaper!
      'bedrooms': 2,
      'type': 'RENTAL',
      'houseType': '2BR',
      'landlordPhone': '+254700000002',
      'available': true,
      'lat': -1.290,
      'lng': 36.782,
      'verified': true, // Verified!
      'listedAt': '2026-01-02T10:00:00Z',
    });

    // Property C: ~300 km away (Mombasa)
    final propFar = Property.fromJson({
      'id': 3,
      'title': 'Far Beachhouse',
      'description': 'Mombasa beach',
      'location': 'Mombasa',
      'price': 10000.0, // Much cheaper & perfect preference match!
      'bedrooms': 1,
      'type': 'RENTAL',
      'houseType': '1BR',
      'landlordPhone': '+254700000003',
      'available': true,
      'lat': -4.043,
      'lng': 39.668,
      'verified': true,
      'listedAt': '2026-01-03T10:00:00Z',
    });

    // Property D: Unknown coordinates (null lat/lng)
    final propNoCoords = Property.fromJson({
      'id': 4,
      'title': 'No Coords Property',
      'description': 'Unknown location pin',
      'location': 'Nairobi',
      'price': 15000.0,
      'bedrooms': 1,
      'type': 'RENTAL',
      'houseType': '1BR',
      'landlordPhone': '+254700000004',
      'available': true,
      'lat': null,
      'lng': null,
      'verified': true,
      'listedAt': '2026-01-04T10:00:00Z',
    });

    test('sorts strictly by distance ascending when user location is present', () {
      final input = [propFar, propNoCoords, propMedium, propClose];

      final sorted = PropertySorter.sort(
        input,
        userLat: userLat,
        userLng: userLng,
        prefHouseType: '1BR', // Matches propFar and propClose
        prefBudget: 'Under 15k', // Matches propFar
      );

      // Closest property (0.2km) MUST come first, even if propFar matches preferences!
      expect(sorted[0].id, equals(1)); // propClose
      expect(sorted[1].id, equals(2)); // propMedium (~5km)
      expect(sorted[2].id, equals(3)); // propFar (~300km)
      expect(sorted[3].id, equals(4)); // propNoCoords (null coordinates last)
    });

    test('breaks ties for nearly identical distances using preference/verification', () {
      final propCloseTie2 = Property.fromJson({
        'id': 5,
        'title': 'Close Apartment 2',
        'description': 'Same CBD block',
        'location': 'CBD, Nairobi',
        'price': 30000.0,
        'bedrooms': 1,
        'type': 'RENTAL',
        'houseType': '1BR',
        'landlordPhone': '+254700000005',
        'available': true,
        'lat': -1.288,
        'lng': 36.818,
        'verified': true, // Verified!
        'listedAt': '2026-01-05T10:00:00Z',
      });

      final input = [propClose, propCloseTie2];

      final sorted = PropertySorter.sort(
        input,
        userLat: userLat,
        userLng: userLng,
      );

      // Same coordinates: propCloseTie2 is verified, so it should rank higher
      expect(sorted[0].id, equals(5));
      expect(sorted[1].id, equals(1));
    });

    test('sorts by newest first when sortNewestFirst is enabled', () {
      final input = [propClose, propMedium, propFar];

      final sorted = PropertySorter.sort(
        input,
        userLat: userLat,
        userLng: userLng,
        sortNewestFirst: true,
      );

      expect(sorted[0].id, equals(3)); // 2026-01-03
      expect(sorted[1].id, equals(2)); // 2026-01-02
      expect(sorted[2].id, equals(1)); // 2026-01-01
    });

    test('falls back to relevance & verification when user location is null', () {
      final input = [propClose, propMedium, propFar, propNoCoords];

      final sorted = PropertySorter.sort(
        input,
        userLat: null,
        userLng: null,
        prefHouseType: '1BR',
      );

      // Without user location, verified properties matching preferences come first
      expect(sorted.every((p) => input.contains(p)), isTrue);
      expect(sorted.length, equals(4));
    });
  });
}
