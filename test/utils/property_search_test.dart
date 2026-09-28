import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/utils/property_search.dart';

Property _p(int id, Map<String, dynamic> overrides) {
  return Property.fromJson({
    'id': id,
    'title': 'Listing $id',
    'description': '',
    'location': 'Nairobi',
    'price': 20000.0,
    'bedrooms': 1,
    'type': 'RENTAL',
    'houseType': 'BEDSITTER',
    'landlordPhone': '+254700000000',
    'available': true,
    ...overrides,
  });
}

void main() {
  group('PropertySearch.parse', () {
    test('plain word stays a token and is not structured', () {
      final i = PropertySearch.parse('Kilimani');
      expect(i.tokens, ['kilimani']);
      expect(i.hasStructuredIntent, isFalse);
    });

    test('generic words like "apartment for rent" are ignored', () {
      expect(PropertySearch.parse('Kilimani apartment for rent').tokens, ['kilimani']);
    });

    test('bedsitter spellings and "single room" map to BEDSITTER', () {
      for (final q in ['bedsitter', 'bedsiter', 'bed sitter', 'bedsit', 'single room']) {
        expect(PropertySearch.parse(q).houseType, 'BEDSITTER', reason: q);
      }
    });

    test('bedroom phrasings map to canonical house types', () {
      expect(PropertySearch.parse('2-bedroom').houseType, '2BR');
      expect(PropertySearch.parse('2 br').houseType, '2BR');
      expect(PropertySearch.parse('two bedroom').houseType, '2BR');
      expect(PropertySearch.parse('1bedroom').houseType, '1BR');
      expect(PropertySearch.parse('3+ bedrooms').houseType, '3BR+');
      expect(PropertySearch.parse('studio').houseType, 'STUDIO');
    });

    test('price upper bounds in several formats', () {
      expect(PropertySearch.parse('bedsitter under 20k').maxPrice, 20000);
      expect(PropertySearch.parse('under 20,000').maxPrice, 20000);
      expect(PropertySearch.parse('below 20000').maxPrice, 20000);
      expect(PropertySearch.parse('30k max').maxPrice, 30000);
      expect(PropertySearch.parse('budget 15k').maxPrice, 15000);
      expect(PropertySearch.parse('20k bedsitter').maxPrice, 20000);
    });

    test('price lower bound and ranges', () {
      expect(PropertySearch.parse('over 40k').minPrice, 40000);
      final r = PropertySearch.parse('15k to 25k');
      expect(r.minPrice, 15000);
      expect(r.maxPrice, 25000);
      final shared = PropertySearch.parse('15 to 25k');
      expect(shared.minPrice, 15000);
      expect(shared.maxPrice, 25000);
      final dash = PropertySearch.parse('50000-80000 2 bedroom');
      expect(dash.minPrice, 50000);
      expect(dash.maxPrice, 80000);
      expect(dash.houseType, '2BR');
    });

    test('bedroom ranges and distances are not read as prices', () {
      final beds = PropertySearch.parse('1 to 2 bedroom');
      expect(beds.minPrice, isNull);
      expect(beds.maxPrice, isNull);
      final dist = PropertySearch.parse('within 5 km of cbd');
      expect(dist.maxPrice, isNull);
      expect(dist.tokens, ['cbd']);
      expect(PropertySearch.parse('under 20 minutes to town').maxPrice, isNull);
    });

    test('unfurnished is the opposite of furnished', () {
      final un = PropertySearch.parse('unfurnished bedsit');
      expect(un.unfurnished, isTrue);
      expect(un.furnished, isFalse);
      final f = PropertySearch.parse('semi furnished studio');
      expect(f.furnished, isTrue);
      expect(f.unfurnished, isFalse);
    });

    test('amenity words are recognised', () {
      expect(PropertySearch.parse('swimming pool gym').amenities, containsAll(['pool', 'gym']));
      expect(PropertySearch.parse('a/c 2 br').amenities, contains('ac'));
      expect(PropertySearch.parse('lift').amenities, contains('elevator'));
      expect(PropertySearch.parse('pet-friendly kileleshwa').amenities, contains('petFriendly'));
      expect(PropertySearch.parse('pet-friendly kileleshwa').tokens, ['kileleshwa']);
    });
  });

  group('PropertySearch.matches', () {
    final kilimani = _p(1, {
      'title': 'Modern Bedsitter Near Yaya Centre',
      'buildingName': 'Sunrise Court',
      'location': 'Kilimani, Nairobi',
      'description': 'Quiet compound with a lift and generous storage',
      'price': 18000.0,
      'houseType': 'BEDSITTER',
      'furnished': false,
    });
    final westlands = _p(2, {
      'title': 'Spacious Apartment',
      'location': 'Westlands, Nairobi',
      'description': 'Has a swimming pool and gym',
      'price': 55000.0,
      'bedrooms': 2,
      'houseType': '2BR',
      'furnished': true,
      'pool': true,
      'gym': true,
    });
    final kasarani = _p(3, {
      'title': 'Cozy Studio',
      'location': 'Kasarani, Nairobi',
      'description': 'Close to the hospital',
      'price': 12000.0,
      'houseType': 'STUDIO',
      'furnished': true,
      'customAmenities': ['Backup borehole'],
    });
    final lavington = _p(4, {
      'title': 'Maisonette',
      'location': 'Lavington, Nairobi',
      'description': 'Family home',
      'price': 95000.0,
      'bedrooms': 3,
      'houseType': '3BR+',
      'furnished': false,
      'garden': true,
    });
    final all = [kilimani, westlands, kasarani, lavington];

    List<int> search(String q) {
      final intent = PropertySearch.parse(q);
      return all.where((p) => PropertySearch.matches(p, intent)).map((p) => p.id!).toList();
    }

    test('empty query matches everything', () {
      expect(search(''), [1, 2, 3, 4]);
    });

    test('generic words do not block a location match', () {
      expect(search('kilimani apartment'), [1]);
    });

    test('words can match across different fields', () {
      expect(search('sunrise kilimani'), [1]); // building + location
      expect(search('yaya bedsitter'), [1]); // title + house type
      expect(search('quiet compound'), [1]); // description
    });

    test('house type and price constraints apply', () {
      expect(search('kilimani bedsitter'), [1]);
      expect(search('2 bedroom'), [2]);
      expect(search('three bedroom'), [4]);
      expect(search('under 20k'), [1, 3]);
      expect(search('15k to 60k'), [1, 2]);
    });

    test('amenity words match flags or description wording', () {
      expect(search('pool'), [2]); // flag
      expect(search('gym'), [2]);
      expect(search('lift'), [1]); // only in description
      expect(search('garden'), [4]);
      expect(search('kilimani pool'), isEmpty);
    });

    test('custom amenities and plurals are searchable', () {
      expect(search('borehole'), [3]);
      expect(search('compounds'), [1]);
    });

    test('tolerates small typos in real words', () {
      expect(search('kilimanni'), [1]);
      expect(search('lavingtn'), [4]);
    });

    test('unfurnished excludes furnished listings', () {
      expect(search('unfurnished'), [1, 4]);
      expect(search('furnished'), [2, 3]);
    });

    test('description wording is found', () {
      expect(search('hospital'), [3]);
    });
  });
}
