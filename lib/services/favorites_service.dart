import 'package:shared_preferences/shared_preferences.dart';
import 'package:roost_app/services/auth_service.dart';

class FavoritesService {
  static const String _baseKey = 'favorite_property_ids';

  static Future<String> _getKey() async {
    try {
      final email = await AuthService.getUserEmail();
      if (email != null && email.isNotEmpty) {
        final sanitized = email.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
        return '${_baseKey}_$sanitized';
      }
    } catch (_) {}
    return '${_baseKey}_guest';
  }

  static Future<List<int>> getFavoriteIds() async {
    final key = await _getKey();
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(key) ?? [];
    return list.map((e) => int.parse(e)).toList();
  }

  static Future<bool> isFavorite(int id) async {
    final ids = await getFavoriteIds();
    return ids.contains(id);
  }

  static Future<void> toggle(int id) async {
    final key = await _getKey();
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(key) ?? [];
    final idStr = id.toString();
    if (list.contains(idStr)) {
      list.remove(idStr);
    } else {
      list.add(idStr);
    }
    await prefs.setStringList(key, list);
  }

  static Future<void> remove(int id) async {
    final key = await _getKey();
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(key) ?? [];
    list.remove(id.toString());
    await prefs.setStringList(key, list);
  }

  static Future<void> add(int id) async {
    final key = await _getKey();
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(key) ?? [];
    final idStr = id.toString();
    if (!list.contains(idStr)) {
      list.add(idStr);
      await prefs.setStringList(key, list);
    }
  }

  static Future<void> clearAll() async {
    final key = await _getKey();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
