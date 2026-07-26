/// Parses an ISO-8601 timestamp string returned by the API.
///
/// The backend serializes Java `LocalDateTime` fields with no timezone
/// designator (e.g. `"2026-07-26T02:49:00.123456"`), but the values are
/// actually UTC wall-clock time -- the server itself runs in UTC. Dart's
/// `DateTime.parse` treats a string with no timezone suffix as
/// already-local and performs zero conversion, so without this helper
/// every timestamp from the API silently displays several hours off
/// (exactly the local UTC offset), and any `.toLocal()` call on the
/// result becomes a no-op since the DateTime is already flagged local.
///
/// This forces UTC interpretation by appending `Z` when the string
/// doesn't already carry a zone designator, so a `.toLocal()` afterward
/// actually performs the conversion it looks like it's doing. Safe to
/// use even if the backend starts sending zoned timestamps later --
/// already-zoned strings pass through unchanged.
DateTime? parseServerDateTime(String? value) {
  if (value == null || value.isEmpty) return null;
  final hasZone = value.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(value);
  return DateTime.tryParse(hasZone ? value : '${value}Z');
}
