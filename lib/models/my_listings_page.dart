import 'package:roost_app/models/property.dart';

/// Whole-portfolio listing counts from `GET /api/v2/properties/my-listings`
/// (Roost: `MyListingsPageResponse.Counts`).
///
/// Parsing is deliberately strict, unlike most models in this folder: a
/// missing or mistyped field throws a [FormatException] instead of
/// defaulting to 0. A silent default would show a plausible-looking but
/// wrong number ("0 verified") after a backend rename; a thrown error
/// surfaces the contract break where it can be seen and fixed.
class ListingCounts {
  final int total;
  final int drafts;
  final int available;
  final int rented;
  final int verified;

  const ListingCounts({
    required this.total,
    required this.drafts,
    required this.available,
    required this.rented,
    required this.verified,
  });

  factory ListingCounts.fromJson(Map<String, dynamic> json) {
    return ListingCounts(
      total: _requireInt(json, 'total', 'counts'),
      drafts: _requireInt(json, 'drafts', 'counts'),
      available: _requireInt(json, 'available', 'counts'),
      rented: _requireInt(json, 'rented', 'counts'),
      verified: _requireInt(json, 'verified', 'counts'),
    );
  }
}

/// One page of `GET /api/v2/properties/my-listings` (Roost:
/// `MyListingsPageResponse`):
///
/// ```json
/// {
///   "items":   [ PropertyListItemDto, ... ],
///   "page":    0,
///   "size":    20,
///   "hasNext": true,
///   "counts":  { "total": 42, "drafts": 3, "available": 30,
///                "rented": 9, "verified": 25 }
/// }
/// ```
///
/// Strict like [ListingCounts]: any missing or mistyped envelope field
/// throws a [FormatException]. Each item is still parsed by
/// [Property.fromJson], which tolerates the slim list-item shape by
/// defaulting the fields that shape omits -- a dedicated list-item model
/// is a separate change.
class MyListingsPage {
  final List<Property> items;
  final int page;
  final int size;
  final bool hasNext;
  final ListingCounts counts;

  const MyListingsPage({
    required this.items,
    required this.page,
    required this.size,
    required this.hasNext,
    required this.counts,
  });

  factory MyListingsPage.fromJson(Map<String, dynamic> json) {
    final rawItems = _requireList(json, 'items', 'response');
    final items = <Property>[];
    for (var i = 0; i < rawItems.length; i++) {
      final raw = rawItems[i];
      if (raw is! Map<String, dynamic>) {
        throw FormatException("my-listings response: 'items[$i]' must be an object, got ${raw.runtimeType}");
      }
      items.add(Property.fromJson(raw));
    }
    return MyListingsPage(
      items: items,
      page: _requireInt(json, 'page', 'response'),
      size: _requireInt(json, 'size', 'response'),
      hasNext: _requireBool(json, 'hasNext', 'response'),
      counts: ListingCounts.fromJson(_requireMap(json, 'counts', 'response')),
    );
  }
}

Never _fail(String where, String key, String expected, Object? actual) {
  final got = actual == null ? 'missing or null' : actual.runtimeType.toString();
  throw FormatException("my-listings response: '$where.$key' must be $expected, got $got");
}

int _requireInt(Map<String, dynamic> json, String key, String where) {
  final value = json[key];
  if (value is int) return value;
  _fail(where, key, 'an int', value);
}

bool _requireBool(Map<String, dynamic> json, String key, String where) {
  final value = json[key];
  if (value is bool) return value;
  _fail(where, key, 'a bool', value);
}

List<dynamic> _requireList(Map<String, dynamic> json, String key, String where) {
  final value = json[key];
  if (value is List) return value;
  _fail(where, key, 'a list', value);
}

Map<String, dynamic> _requireMap(Map<String, dynamic> json, String key, String where) {
  final value = json[key];
  if (value is Map<String, dynamic>) return value;
  _fail(where, key, 'an object', value);
}
