import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/models/property.dart';

/// Server-backed saved properties. Was previously a local, per-device
/// SharedPreferences store keyed by the user's email -- it never actually
/// touched the network at all. That meant saved properties didn't sync
/// across devices or survive a reinstall, and PropertyController's
/// save/unsave/saved endpoints (and Property.saveCount, meant to show
/// landlords how many people saved their listing) were built but never
/// actually called from the app.
///
/// Kept the same public method names/signatures as the old local version
/// so callers (main.dart's home feed, property_detail_page.dart's save
/// button) didn't need any changes -- only what happens inside changed.
class FavoritesService {
  static Future<List<int>> getFavoriteIds() async {
    final saved = await getSavedProperties();
    return saved.where((p) => p.id != null).map((p) => p.id!).toList();
  }

  /// Full Property objects for everything the user has saved -- used
  /// directly by the Saved page instead of it fetching every property
  /// and cross-referencing IDs client-side.
  static Future<List<Property>> getSavedProperties() async {
    final jsonList = await ApiService.get('/api/properties/saved');
    if (jsonList is! List) return [];
    return jsonList.map((j) => Property.fromJson(j)).toList();
  }

  static Future<bool> isFavorite(int id) async {
    final ids = await getFavoriteIds();
    return ids.contains(id);
  }

  static Future<void> toggle(int id) async {
    if (await isFavorite(id)) {
      await remove(id);
    } else {
      await add(id);
    }
  }

  static Future<void> remove(int id) async {
    await ApiService.delete('/api/properties/$id/save');
  }

  static Future<void> add(int id) async {
    await ApiService.post('/api/properties/$id/save');
  }

  /// No bulk "unsave all" endpoint on the backend -- saved lists are
  /// small in practice, so this just removes each one individually.
  static Future<void> clearAll() async {
    final ids = await getFavoriteIds();
    await Future.wait(ids.map(remove));
  }
}
