import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roost_app/config.dart';
import 'package:roost_app/models/country_config.dart';
import 'package:roost_app/services/country_service.dart';

void main() {
  group('CountryConfig.mapCenter', () {
    test('every supported country has a distinct, non-zero map center', () {
      final centers = CountryConfig.all.map((c) => c.mapCenter).toSet();
      // toSet() de-duplicates by LatLng's value equality, so this also
      // catches a copy-paste that gave two countries the same center.
      expect(centers.length, CountryConfig.all.length);
      for (final country in CountryConfig.all) {
        expect(country.mapCenter, isNot(const LatLng(0, 0)),
            reason: '${country.name} has an unset map center');
      }
    });

    test('Kenya centers on Nairobi (unchanged default)', () {
      expect(CountryConfig.kenya.mapCenter, const LatLng(-1.2921, 36.8219));
    });
  });

  group('AppConfig.defaultMapCenter', () {
    // CountryService.setCountry() updates its in-memory _current field
    // synchronously before it ever awaits SharedPreferences -- see the
    // service's own implementation -- so it's safe to check the effect
    // immediately. The SharedPreferences.getInstance() call after that has
    // no platform mock in a plain unit test and throws; that's expected
    // and irrelevant to what's being tested here, so it's swallowed.
    Future<void> setCountryIgnoringPersistenceFailure(CountryConfig country) async {
      try {
        await CountryService.instance.setCountry(country);
      } catch (_) {}
    }

    setUp(() {
      // CountryService is a singleton with mutable state; leave it as we
      // found it so other test files aren't affected by run order.
      addTearDown(() => setCountryIgnoringPersistenceFailure(CountryConfig.kenya));
    });

    test('follows the currently selected country, not a hardcoded Nairobi constant', () async {
      await setCountryIgnoringPersistenceFailure(CountryConfig.unitedKingdom);
      expect(AppConfig.defaultMapCenter, CountryConfig.unitedKingdom.mapCenter);

      await setCountryIgnoringPersistenceFailure(CountryConfig.nigeria);
      expect(AppConfig.defaultMapCenter, CountryConfig.nigeria.mapCenter);
    });
  });
}
