import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Dark Google Maps style JSON matching Roost's monochrome black/white aesthetic.
///
/// IMPORTANT: if the Google Maps SDK finds ANY unrecognized featureType,
/// unrecognized elementType, or invalid styler key anywhere in this array,
/// it silently discards the WHOLE style and falls back to the default
/// light/colorful Google map -- no exception, no visible error, nothing in
/// logcat by default. This previously happened here: "building" is not a
/// real featureType (buildings fall under "landscape.man_made" instead),
/// so the entire style was being rejected and every map in the app was
/// rendering as plain default Google Maps. See
/// https://developers.google.com/maps/documentation/android-sdk/style-reference
/// for the full list of valid featureType/elementType/styler values before
/// adding new rules here, and call GoogleMapController.getStyleError()
/// after onMapCreated (see InAppMapPage/MapViewPage) so a future mistake
/// like this one surfaces immediately instead of silently again.
class AppMapStyle {
  AppMapStyle._();

  /// Call from `onMapCreated` on every map that sets [darkMapStyle] (or any
  /// future style string). The SDK never throws or logs on its own when a
  /// style is rejected -- see the class doc above -- so without this check
  /// the only symptom is a map that silently isn't themed, exactly as
  /// happened before this existed.
  static void checkStyleApplied(GoogleMapController controller) {
    controller.getStyleError().then((error) {
      if (error != null) {
        debugPrint('AppMapStyle.darkMapStyle was rejected by the Google Maps SDK: $error');
      }
    });
  }

  static const String darkMapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [
      { "color": "#1c1c1e" }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#8e8e93" }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      { "color": "#1c1c1e" }
    ]
  },
  {
    "featureType": "administrative",
    "elementType": "geometry",
    "stylers": [
      { "color": "#2c2c2e" }
    ]
  },
  {
    "featureType": "administrative.country",
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#aeaeb2" }
    ]
  },
  {
    "featureType": "administrative.locality",
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#ffffff" }
    ]
  },
  {
    "featureType": "landscape.man_made",
    "elementType": "geometry",
    "stylers": [
      { "color": "#252527" }
    ]
  },
  {
    "featureType": "landscape.man_made",
    "elementType": "geometry.stroke",
    "stylers": [
      { "color": "#1c1c1e" }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#8e8e93" }
    ]
  },
  {
    "featureType": "poi.business",
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#8e8e93" }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry",
    "stylers": [
      { "color": "#121214" }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#6b6b70" }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#2c2c2e" }
    ]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#8e8e93" }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [
      { "color": "#3a3a3c" }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.stroke",
    "stylers": [
      { "color": "#1c1c1e" }
    ]
  },
  {
    "featureType": "transit",
    "elementType": "geometry",
    "stylers": [
      { "color": "#2c2c2e" }
    ]
  },
  {
    "featureType": "transit.station",
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#8e8e93" }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [
      { "color": "#0a0a0c" }
    ]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#48484a" }
    ]
  }
]
''';
}
