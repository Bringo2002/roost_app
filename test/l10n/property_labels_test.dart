import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roost_app/l10n/generated/app_localizations.dart';
import 'package:roost_app/l10n/property_labels.dart';
import 'package:roost_app/models/property.dart';

Property _property({int bedrooms = 1, String houseType = 'BEDSITTER'}) {
  return Property(
    title: 'Test listing',
    description: 'Test',
    location: 'Nairobi',
    price: 20000,
    bedrooms: bedrooms,
    type: 'RENTAL',
    landlordPhone: '+254712345678',
    available: true,
    houseType: houseType,
  );
}

void main() {
  group('Property.bedroomLabel (English)', () {
    late AppLocalizations l10n;

    setUpAll(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('singular and plural bedroom counts', () {
      expect(_property(bedrooms: 1).bedroomLabel(l10n), '1 bed');
      expect(_property(bedrooms: 3).bedroomLabel(l10n), '3 beds');
    });

    test('zero bedrooms uses the house type', () {
      expect(_property(bedrooms: 0, houseType: 'BEDSITTER').bedroomLabel(l10n), 'Bedsitter');
      expect(_property(bedrooms: 0, houseType: 'bedsitter').bedroomLabel(l10n), 'Bedsitter');
      expect(_property(bedrooms: 0, houseType: 'STUDIO').bedroomLabel(l10n), 'Studio');
    });

    test('zero bedrooms with an unknown house type falls back to Studio', () {
      expect(_property(bedrooms: 0, houseType: 'MANSION').bedroomLabel(l10n), 'Studio');
    });
  });

  group('Property.bedroomLabel (Swahili)', () {
    late AppLocalizations l10n;

    setUpAll(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('sw'));
    });

    test('is actually translated, not the English fallback', () {
      expect(_property(bedrooms: 1).bedroomLabel(l10n), 'chumba 1');
      expect(_property(bedrooms: 3).bedroomLabel(l10n), 'vyumba 3');
    });
  });
}
