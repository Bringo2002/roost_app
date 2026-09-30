import 'package:roost_app/models/property.dart';

/// Pure filter/sort rules for the landlord "My Listings" dashboard.
///
/// Kept out of [LandlordDashboardPage]'s State so both can be unit-tested
/// directly -- no widget pump, no network round trip -- the same pattern
/// already used for the search feed's [PropertySorter].
///
/// The dashboard's own list/count fetch is now paginated and filtered
/// server-side (GET /api/v2/properties/my-listings) using the identical
/// predicates below, so [applyFilter] is no longer used to filter the
/// dashboard's own data -- but [matches] still is, to decide whether an
/// item that changed status/availability locally (after an optimistic
/// toggle or publish) should be removed from the currently-selected
/// filter's view without waiting for a reload.
class LandlordListingOrganizer {
  LandlordListingOrganizer._();

  static const String filterAll = 'ALL';
  static const String filterPublished = 'PUBLISHED';
  static const String filterDraft = 'DRAFT';
  static const String filterRented = 'RENTED';

  /// Draft listings first, everything else after -- stable within each
  /// group. Sorts [properties] in place and returns it for convenience.
  static List<Property> sortDraftsFirst(List<Property> properties) {
    properties.sort(
      (a, b) => a.status == b.status ? 0 : (a.status == filterDraft ? -1 : 1),
    );
    return properties;
  }

  /// Whether [property] belongs to one of the dashboard's stat-card /
  /// filter-chip buckets. [filterAll] and any unrecognized value match
  /// everything. Mirrors PropertyRepository#findOwnerListingsPage and
  /// #countOwnerListings on the backend exactly -- these three predicates
  /// must stay identical to those, or a chip's badge count (server-side
  /// now) stops matching what tapping that chip shows.
  static bool matches(Property property, String filter) {
    switch (filter) {
      case filterPublished:
        return property.status == filterPublished && property.available;
      case filterDraft:
        return property.status == filterDraft;
      case filterRented:
        return !property.available;
      case filterAll:
      default:
        return true;
    }
  }

  /// Applies one of the dashboard's stat-card / filter-chip selections to
  /// a whole list. Unrecognized filter values (including [filterAll])
  /// return the list unchanged.
  static List<Property> applyFilter(List<Property> properties, String filter) {
    if (filter != filterAll &&
        filter != filterPublished &&
        filter != filterDraft &&
        filter != filterRented) {
      return properties;
    }
    return properties.where((p) => matches(p, filter)).toList();
  }
}
