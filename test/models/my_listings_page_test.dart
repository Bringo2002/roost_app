import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/models/my_listings_page.dart';

/// One PropertyListItemDto exactly as Roost serializes it (field names
/// from PropertyListItemDto.java).
Map<String, dynamic> _slimItem({required int id, String title = 'Cozy Bedsitter', String status = 'PUBLISHED'}) {
  return {
    'id': id,
    'title': title,
    'location': 'Kilimani, Nairobi',
    'price': 25000.0,
    'bedrooms': 1,
    'type': 'RENTAL',
    'available': true,
    'imageUrl': 'https://cdn.example.com/a.jpg',
    'verified': false,
    'gpsVerified': true,
    'status': status,
    'listedAt': '2026-03-14T10:15:30',
    'landlordEndorsed': false,
    'endorsementToken': null,
    'ownerVerifyName': null,
    'ownerVerifyPhone': null,
    'managerRole': 'LANDLORD',
  };
}

/// A full MyListingsPageResponse exactly as Roost serializes it (field
/// names from MyListingsPageResponse.java).
Map<String, dynamic> _envelope() {
  return {
    'items': [_slimItem(id: 1), _slimItem(id: 2, title: 'Second', status: 'DRAFT')],
    'page': 1,
    'size': 20,
    'hasNext': true,
    // Explicit type: an untyped literal here is inferred as Map<String, int>,
    // which would make the tests below that assign a String or null into it
    // fail with a TypeError inside the test itself, never reaching the parser.
    'counts': <String, dynamic>{'total': 42, 'drafts': 3, 'available': 30, 'rented': 9, 'verified': 25},
  };
}

Matcher _formatErrorMentioning(String fragment) =>
    throwsA(isA<FormatException>().having((e) => e.message, 'message', contains(fragment)));

void main() {
  group('MyListingsPage.fromJson', () {
    test('parses the envelope exactly as the backend serializes it', () {
      final page = MyListingsPage.fromJson(_envelope());

      expect(page.page, 1);
      expect(page.size, 20);
      expect(page.hasNext, isTrue);
      expect(page.counts.total, 42);
      expect(page.counts.drafts, 3);
      expect(page.counts.available, 30);
      expect(page.counts.rented, 9);
      expect(page.counts.verified, 25);
      expect(page.items.map((p) => p.id), [1, 2]);
      expect(page.items.first.title, 'Cozy Bedsitter');
      expect(page.items.first.gpsVerified, isTrue);
      expect(page.items.last.status, 'DRAFT');
    });

    test('parses a final, empty page', () {
      final json = _envelope()
        ..['items'] = <dynamic>[]
        ..['hasNext'] = false;

      final page = MyListingsPage.fromJson(json);

      expect(page.items, isEmpty);
      expect(page.hasNext, isFalse);
    });

    for (final key in ['items', 'page', 'size', 'hasNext', 'counts']) {
      test("throws, naming the field, when '$key' is missing", () {
        final json = _envelope()..remove(key);

        expect(() => MyListingsPage.fromJson(json), _formatErrorMentioning("'response.$key'"));
      });
    }

    test("throws when 'hasNext' is a string instead of a bool", () {
      final json = _envelope()..['hasNext'] = 'true';

      expect(() => MyListingsPage.fromJson(json), _formatErrorMentioning("'response.hasNext'"));
    });

    test("throws when 'items' is not a list", () {
      final json = _envelope()..['items'] = {'id': 1};

      expect(() => MyListingsPage.fromJson(json), _formatErrorMentioning("'response.items'"));
    });

    test('throws, naming the index, when an item is not an object', () {
      final json = _envelope()..['items'] = [_slimItem(id: 1), 'not-an-object'];

      expect(() => MyListingsPage.fromJson(json), _formatErrorMentioning("'items[1]'"));
    });
  });

  group('ListingCounts.fromJson', () {
    for (final key in ['total', 'drafts', 'available', 'rented', 'verified']) {
      test("throws, naming the field, when counts.'$key' is missing", () {
        final json = _envelope();
        (json['counts'] as Map<String, dynamic>).remove(key);

        expect(() => MyListingsPage.fromJson(json), _formatErrorMentioning("'counts.$key'"));
      });
    }

    test('throws when a count is a string instead of an int', () {
      final json = _envelope();
      (json['counts'] as Map<String, dynamic>)['total'] = '42';

      expect(() => MyListingsPage.fromJson(json), _formatErrorMentioning("'counts.total'"));
    });

    test('throws when a count is null', () {
      final json = _envelope();
      (json['counts'] as Map<String, dynamic>)['verified'] = null;

      expect(() => MyListingsPage.fromJson(json), _formatErrorMentioning("'counts.verified'"));
    });
  });
}
