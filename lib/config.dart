import 'package:google_maps_flutter/google_maps_flutter.dart';

class AppConfig {
  static const String baseUrl = 'https://roost-production-336e.up.railway.app';
  static const String baseurl = baseUrl;

  /// Fallback map center (Nairobi CBD) used whenever a property has no
  /// pinned latitude/longitude yet. Was previously duplicated as raw
  /// -1.2921/36.8219 literals across the map preview and in-app map page.
  static const LatLng defaultMapCenter = LatLng(-1.2921, 36.8219);
}