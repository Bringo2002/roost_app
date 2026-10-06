import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/theme/amenity_colors.dart';

void main() {
  group('AmenityColors', () {
    // Exact-value locks: these replaced raw literals as a no-visual-change
    // refactor. Compare ARGB ints, not Color objects.
    final expected = <String, List<int>>{
      'water': [AmenityColors.water.toARGB32(), 0xFF29B6F6],
      'generator': [AmenityColors.generator.toARGB32(), 0xFFFFB74D],
      'solar': [AmenityColors.solar.toARGB32(), 0xFFFFD54F],
      'ac': [AmenityColors.ac.toARGB32(), 0xFF81D4FA],
      'heating': [AmenityColors.heating.toARGB32(), 0xFFFF8A65],
      'laundry': [AmenityColors.laundry.toARGB32(), 0xFF90CAF9],
      'dstv': [AmenityColors.dstv.toARGB32(), 0xFFAB47BC],
      'security': [AmenityColors.security.toARGB32(), 0xFFFF9F43],
      'fence': [AmenityColors.fence.toARGB32(), 0xFFFF7043],
      'intercom': [AmenityColors.intercom.toARGB32(), 0xFFBA68C8],
      'elevator': [AmenityColors.elevator.toARGB32(), 0xFF4DB6AC],
      'parking': [AmenityColors.parking.toARGB32(), 0xFF4FC3F7],
      'caretaker': [AmenityColors.caretaker.toARGB32(), 0xFFA1887F],
      'balcony': [AmenityColors.balcony.toARGB32(), 0xFFA5D6A7],
      'rooftop': [AmenityColors.rooftop.toARGB32(), 0xFFB39DDB],
      'garden': [AmenityColors.garden.toARGB32(), 0xFF81C784],
      'storage': [AmenityColors.storage.toARGB32(), 0xFFDCE775],
      'pool': [AmenityColors.pool.toARGB32(), 0xFF4DD0E1],
      'gym': [AmenityColors.gym.toARGB32(), 0xFFFF8A65],
      'playArea': [AmenityColors.playArea.toARGB32(), 0xFFF48FB1],
      'petFriendly': [AmenityColors.petFriendly.toARGB32(), 0xFFEF9A9A],
      'cleaning': [AmenityColors.cleaning.toARGB32(), 0xFF80CBC4],
      'garbage': [AmenityColors.garbage.toARGB32(), 0xFFB0BEC5],
      'wheelchair': [AmenityColors.wheelchair.toARGB32(), 0xFF9FA8DA],
    };

    expected.forEach((name, pair) {
      test('$name keeps its original value', () {
        expect(pair[0], pair[1]);
      });
    });

    test('every amenity color is fully opaque', () {
      for (final pair in expected.values) {
        expect(pair[0] >> 24, 0xFF);
      }
    });
  });
}
