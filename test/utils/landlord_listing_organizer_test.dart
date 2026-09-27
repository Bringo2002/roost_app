import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/utils/landlord_listing_organizer.dart';

Property _property({
  required int id,
  String status = 'PUBLISHED',
  bool available = true,
}) {
  return Property(
    id: id,
    title: 'Listing $id',
    description: 'desc',
    location: 'Nairobi',
    price: 10000,
    bedrooms: 1,
    type: 'RENTAL',
    landlordPhone: '+254700000000',
    available: available,
    status: status,
  );
}

void main() {
  group('LandlordListingOrganizer.sortDraftsFirst', () {
    test('moves all DRAFT listings ahead of everything else', () {
      final listings = [
        _property(id: 1, status: 'PUBLISHED'),
        _property(id: 2, status: 'DRAFT'),
        _property(id: 3, status: 'PUBLISHED'),
        _property(id: 4, status: 'DRAFT'),
      ];

      final sorted = LandlordListingOrganizer.sortDraftsFirst(listings);

      expect(sorted.take(2).map((p) => p.status), everyElement('DRAFT'));
      expect(sorted.skip(2).map((p) => p.status), everyElement('PUBLISHED'));
    });

    test('is a no-op when there are no drafts', () {
      final listings = [
        _property(id: 1, status: 'PUBLISHED'),
        _property(id: 2, status: 'PUBLISHED'),
      ];

      final sorted = LandlordListingOrganizer.sortDraftsFirst(listings);

      expect(sorted.map((p) => p.id), [1, 2]);
    });

    test('sorts in place and returns the same list instance', () {
      final listings = [
        _property(id: 1, status: 'PUBLISHED'),
        _property(id: 2, status: 'DRAFT'),
      ];

      final result = LandlordListingOrganizer.sortDraftsFirst(listings);

      expect(identical(result, listings), isTrue);
    });
  });

  group('LandlordListingOrganizer.applyFilter', () {
    final listings = [
      _property(id: 1, status: 'PUBLISHED', available: true),
      _property(id: 2, status: 'DRAFT', available: true),
      _property(id: 3, status: 'PUBLISHED', available: false),
      _property(id: 4, status: 'DRAFT', available: false),
    ];

    test('ALL returns every listing unchanged', () {
      final result = LandlordListingOrganizer.applyFilter(listings, LandlordListingOrganizer.filterAll);
      expect(result.map((p) => p.id), [1, 2, 3, 4]);
    });

    test('PUBLISHED returns only published AND available listings', () {
      final result =
          LandlordListingOrganizer.applyFilter(listings, LandlordListingOrganizer.filterPublished);
      expect(result.map((p) => p.id), [1]);
    });

    test('DRAFT returns only draft listings regardless of availability', () {
      final result = LandlordListingOrganizer.applyFilter(listings, LandlordListingOrganizer.filterDraft);
      expect(result.map((p) => p.id), [2, 4]);
    });

    test('RENTED returns only unavailable listings regardless of status', () {
      final result =
          LandlordListingOrganizer.applyFilter(listings, LandlordListingOrganizer.filterRented);
      expect(result.map((p) => p.id), [3, 4]);
    });

    test('an unrecognized filter value falls back to the full list', () {
      final result = LandlordListingOrganizer.applyFilter(listings, 'SOMETHING_ELSE');
      expect(result.map((p) => p.id), [1, 2, 3, 4]);
    });
  });
}
