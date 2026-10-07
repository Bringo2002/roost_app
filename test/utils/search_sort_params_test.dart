import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/utils/search_sort_params.dart';

void main() {
  group('searchSortParams', () {
    test('default order asks for nearest-first when the position is known', () {
      expect(
        searchSortParams(recommended: false, newestFirst: false, lat: -1.28, lng: 36.82),
        {'lat': '-1.28', 'lng': '36.82'},
      );
    });

    test('default order sends nothing when the position is unknown', () {
      expect(searchSortParams(recommended: false, newestFirst: false), isEmpty);
    });

    test('a half-known position is treated as unknown', () {
      expect(searchSortParams(recommended: false, newestFirst: false, lat: -1.28), isEmpty);
      expect(searchSortParams(recommended: false, newestFirst: false, lng: 36.82), isEmpty);
    });

    test('newest-first omits location even when it is known', () {
      expect(
        searchSortParams(recommended: false, newestFirst: true, lat: -1.28, lng: 36.82),
        isEmpty,
      );
    });

    test('recommended asks for the recommended order and omits location', () {
      expect(
        searchSortParams(recommended: true, newestFirst: false, lat: -1.28, lng: 36.82),
        {'sort': 'recommended'},
      );
    });

    test('recommended wins if newest-first is somehow set as well', () {
      expect(
        searchSortParams(recommended: true, newestFirst: true),
        {'sort': 'recommended'},
      );
    });
  });
}
