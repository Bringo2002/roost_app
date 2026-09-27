import 'package:roost_app/models/property.dart';

/// Pure filter/sort rules for the landlord "My Listings" dashboard.
///
/// Kept out of [LandlordDashboardPage]'s State so both can be unit-tested
/// directly -- no widget pump, no network round trip -- the same pattern
/// already used for the search feed's [PropertySorter].
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

  /// Applies one of the dashboard's stat-card / filter-chip selections.
  /// Unrecognized filter values (including [filterAll]) return the full
  /// list unchanged.
  static List<Property> applyFilter(List<Property> properties, String filter) {
    switch (filter) {
      case filterPublished:
        return properties.where((p) => p.status == filterPublished && p.available).toList();
      case filterDraft:
        return properties.where((p) => p.status == filterDraft).toList();
      case filterRented:
        return properties.where((p) => !p.available).toList();
      case filterAll:
      default:
        return properties;
    }
  }
}
