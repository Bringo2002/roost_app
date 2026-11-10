/// A state as the backend names it on the wire, e.g. `NOT_ATTEMPTED`.
abstract interface class _WireValue {
  String get wire;
}

/// The listing owner's phone number.
enum PhoneState implements _WireValue {
  unverified('UNVERIFIED'),
  pending('PENDING'),
  verified('VERIFIED');

  const PhoneState(this.wire);
  @override
  final String wire;
}

/// Whether the listing has a pinned location.
enum LocationState implements _WireValue {
  unconfirmed('UNCONFIRMED'),
  confirmed('CONFIRMED'),
  changed('CHANGED');

  const LocationState(this.wire);
  @override
  final String wire;
}

/// Whether the lister has been checked as physically present at the pin.
enum OnSiteState implements _WireValue {
  notAttempted('NOT_ATTEMPTED'),
  pending('PENDING'),
  passed('PASSED'),
  failed('FAILED');

  const OnSiteState(this.wire);
  @override
  final String wire;
}

/// The listing's photos.
enum PhotosState implements _WireValue {
  notSubmitted('NOT_SUBMITTED'),
  submitted('SUBMITTED'),
  underReview('UNDER_REVIEW'),
  approved('APPROVED'),
  rejected('REJECTED');

  const PhotosState(this.wire);
  @override
  final String wire;
}

/// Supporting documents. Uploading one never implies it was accepted.
enum DocumentsState implements _WireValue {
  notSubmitted('NOT_SUBMITTED'),
  uploaded('UPLOADED'),
  underReview('UNDER_REVIEW'),
  accepted('ACCEPTED'),
  rejected('REJECTED');

  const DocumentsState(this.wire);
  @override
  final String wire;
}

/// Whether the lister is the owner or authorised to list for them.
enum AuthorityState implements _WireValue {
  notEstablished('NOT_ESTABLISHED'),
  pending('PENDING'),
  confirmed('CONFIRMED'),
  rejected('REJECTED');

  const AuthorityState(this.wire);
  @override
  final String wire;
}

/// What Roost has and hasn't checked about a listing, as the backend reports
/// it to the listing's owner. Mirrors `PropertyVerification` in the `Roost`
/// backend, the one place the states and the Verified badge are defined: the
/// app shows these instead of working them out from its own flags.
///
/// Not sent to anyone but the owner, so a `Property` from a public endpoint
/// has none.
class PropertyVerification {
  /// Creates a verification snapshot.
  const PropertyVerification({
    required this.phone,
    required this.location,
    required this.onSite,
    required this.photos,
    required this.documents,
    required this.authority,
    required this.badgeEarned,
  });

  /// Parses the backend's `verification` object. An unknown state or a missing
  /// key is a contract break and throws rather than being defaulted.
  factory PropertyVerification.fromJson(Map<String, dynamic> json) {
    return PropertyVerification(
      phone: _parse(PhoneState.values, json['phone'], 'phone'),
      location: _parse(LocationState.values, json['location'], 'location'),
      onSite: _parse(OnSiteState.values, json['onSite'], 'onSite'),
      photos: _parse(PhotosState.values, json['photos'], 'photos'),
      documents: _parse(DocumentsState.values, json['documents'], 'documents'),
      authority: _parse(AuthorityState.values, json['authority'], 'authority'),
      badgeEarned: json['badgeEarned'] as bool,
    );
  }

  final PhoneState phone;
  final LocationState location;
  final OnSiteState onSite;
  final PhotosState photos;
  final DocumentsState documents;
  final AuthorityState authority;

  /// Whether the Verified badge is earned. The backend's decision, never
  /// recomputed here.
  final bool badgeEarned;

  static T _parse<T extends _WireValue>(
      List<T> values, Object? raw, String field) {
    for (final value in values) {
      if (value.wire == raw) return value;
    }
    throw FormatException('Unknown $field state "$raw"');
  }
}
