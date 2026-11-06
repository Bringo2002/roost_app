/// One reason the backend refused to publish a listing.
///
/// Mirrors `PublicationViolation` in the `Roost` backend: the `violations`
/// list that accompanies the `error` message when a listing fails its
/// publication rules.
class PublicationViolation {
  /// Creates a violation.
  const PublicationViolation({
    required this.field,
    required this.code,
    required this.message,
  });

  /// Parses one entry of the response's `violations` list. A missing or
  /// mistyped key is a contract break and throws rather than being defaulted.
  factory PublicationViolation.fromJson(Map<String, dynamic> json) {
    return PublicationViolation(
      field: json['field'] as String,
      code: json['code'] as String,
      message: json['message'] as String,
    );
  }

  /// The listing input the problem is about, e.g. `title` or `imageUrls`.
  final String field;

  /// Stable machine-readable identifier, e.g. `TITLE_REQUIRED`.
  final String code;

  /// User-facing explanation of what to fix.
  final String message;
}
