import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static const String _key = 'favorite_property_ids';

  static Future<List<int>> getFavoriteIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    return list.map((e) => int.parse(e)).toList();
  }

  static Future<bool> isFavorite(int id) async {
    final ids = await getFavoriteIds();
    return ids.contains(id);
  }

  static Future<void> toggle(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    final idStr = id.toString();
    if (list.contains(idStr)) {
      list.remove(idStr);
    } else {
      list.add(idStr);
    }
    await prefs.setStringList(_key, list);
  }

  static Future<void> remove(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    list.remove(id.toString());
    await prefs.setStringList(_key, list);
  }

  static Future<void> add(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    final idStr = id.toString();
    if (!list.contains(idStr)) {
      list.add(idStr);
      await prefs.setStringList(_key, list);
    }
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
