/// Query parameters that choose the server-side order for the Search page's
/// GET /api/properties/filter request.
///
/// The server's page boundaries follow whichever order it was asked for, so
/// the client must ask for the same order it displays -- otherwise "next page"
/// stops meaning "the next chunk of what is on screen".
///
/// * [recommended]: `sort=recommended` -- the server orders by its stored
///   ranking score. It ignores location in that mode, so lat/lng are left out.
///   Wins over [newestFirst] if both are set (the filter sheet never sets both).
/// * [newestFirst]: no lat/lng, so the server falls back to newest-first.
/// * otherwise: lat/lng when both are known, so the server orders nearest
///   first; nothing when the user's position is unknown.
Map<String, String> searchSortParams({
  required bool recommended,
  required bool newestFirst,
  double? lat,
  double? lng,
}) {
  if (recommended) return const {'sort': 'recommended'};
  if (newestFirst || lat == null || lng == null) return const {};
  return {'lat': '$lat', 'lng': '$lng'};
}
