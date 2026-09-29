import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roost_app/services/country_service.dart';

class AppConfig {
  static const String baseUrl = 'https://roost-production-336e.up.railway.app';
  static const String baseurl = baseUrl;

  /// Fallback map center used whenever a property has no pinned
  /// latitude/longitude yet. Was previously a hardcoded Nairobi constant
  /// duplicated across the map preview and in-app map page, which put
  /// renters in the UK or UAE looking at a map centered on Kenya. Now
  /// follows the user's selected/detected country (CountryService
  /// defaults to Kenya itself before a country is chosen, so this is
  /// always safe to read synchronously).
  static LatLng get defaultMapCenter => CountryService.instance.current.mapCenter;
}