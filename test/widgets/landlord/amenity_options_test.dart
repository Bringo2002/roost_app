import 'package:flutter_test/flutter_test.dart';

import 'package:roost_app/widgets/landlord/amenity_options.dart';

void main() {
  group('kAmenityOptions', () {
    test('has no duplicate keys', () {
      final keys = kAmenityOptions.map((a) => a.key).toList();

      expect(keys.toSet(), hasLength(keys.length));
    });

    test('has no duplicate labels', () {
      final labels = kAmenityOptions.map((a) => a.label).toList();

      expect(labels.toSet(), hasLength(labels.length));
    });

    test('gives every option a key and a label', () {
      for (final option in kAmenityOptions) {
        expect(option.key, isNotEmpty);
        expect(option.label, isNotEmpty);
      }
    });

    test('covers every amenity the listing payload reads', () {
      const payloadKeys = {
        'furnished', 'parking', 'wifi', 'water', 'security', 'balcony',
        'petFriendly', 'ac', 'heating', 'laundry', 'dstv', 'fence',
        'intercom', 'elevator', 'caretaker', 'rooftop', 'garden',
        'storage', 'pool', 'gym', 'generator', 'solar', //
      };

      final keys = kAmenityOptions.map((a) => a.key).toSet();

      expect(keys, containsAll(payloadKeys));
    });
  });
}
