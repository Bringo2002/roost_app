import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Per-device "recent searches" for the property search box (SearchPage).
/// Purely local -- there's no backend concept of search history, and
/// there doesn't need to be; this is the same kind of per-device,
/// no-sync-needed data as a draft, not something a user would expect
/// to follow them to a new phone.
///
/// Most-recent-first, deduplicated case-insensitively (typing "Kilimani"
/// twice shouldn't produce two entries), capped at [_maxEntries] so this
/// can't grow without bound over the life of an install.
class RecentSearchesService {
  RecentSearchesService._();

  static const String _prefsKey = 'recent_searches';
  static const int _maxEntries = 8;

  static Future<List<String>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<String>().toList();
    } catch (_) {
      // Corrupt/old-format value (e.g. a future app version changes the
      // encoding) -- treat as empty rather than crashing the search page.
      return [];
    }
  }

  /// Records [query] as the most recent search, moving it to the front
  /// if it (case-insensitively) already appears. Blank queries are
  /// ignored -- they don't represent a search worth remembering.
  static Future<void> add(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final current = await getAll();
    final deduped = [
      trimmed,
      ...current.where((q) => q.toLowerCase() != trimmed.toLowerCase()),
    ];
    final capped = deduped.take(_maxEntries).toList();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(capped));
  }

  static Future<void> remove(String query) async {
    final current = await getAll();
    final filtered = current.where((q) => q != query).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(filtered));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
