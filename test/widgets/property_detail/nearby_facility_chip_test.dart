import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roost_app/l10n/generated/app_localizations.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/widgets/property_detail/nearby_facility_chip.dart';

NearbyFacility _facility({
  String name = 'TRM Mall',
  String category = 'mall',
  double distanceMeters = 600,
}) {
  return NearbyFacility(
    name: name,
    category: category,
    distanceMeters: distanceMeters,
    latitude: -1.2,
    longitude: 36.9,
  );
}

Widget _host(Widget child, {Locale locale = const Locale('en'), double? width}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(
        child: width == null ? child : SizedBox(width: width, child: child),
      ),
    ),
  );
}

void main() {
  group('NearbyFacilityChip label', () {
    testWidgets('shows metres under 1km', (tester) async {
      await tester.pumpWidget(_host(NearbyFacilityChip(facility: _facility())));
      expect(find.text('600m from TRM Mall'), findsOneWidget);
    });

    testWidgets('shows km to one decimal from 1km up', (tester) async {
      await tester.pumpWidget(_host(NearbyFacilityChip(
        facility: _facility(name: 'Thika Superhighway', category: 'road', distanceMeters: 1234),
      )));
      expect(find.text('1.2km from Thika Superhighway'), findsOneWidget);
    });

    testWidgets('999.6m rounds up to 1.0km, never "1000m"', (tester) async {
      await tester.pumpWidget(_host(NearbyFacilityChip(
        facility: _facility(distanceMeters: 999.6),
      )));
      expect(find.text('1.0km from TRM Mall'), findsOneWidget);
      expect(find.textContaining('1000m'), findsNothing);
    });

    testWidgets('is localized to Swahili', (tester) async {
      await tester.pumpWidget(_host(
        NearbyFacilityChip(facility: _facility()),
        locale: const Locale('sw'),
      ));
      expect(find.text('600m kutoka TRM Mall'), findsOneWidget);
    });
  });

  group('NearbyFacilityChip icon', () {
    testWidgets('uses a category-specific icon', (tester) async {
      const expected = {
        'mall': Icons.shopping_bag_outlined,
        'hospital': Icons.local_hospital_outlined,
        'road': Icons.add_road_outlined,
        'something-else': Icons.place_outlined,
      };
      for (final entry in expected.entries) {
        await tester.pumpWidget(_host(
          NearbyFacilityChip(key: ValueKey(entry.key), facility: _facility(category: entry.key)),
        ));
        expect(find.byIcon(entry.value), findsOneWidget, reason: entry.key);
      }
    });
  });

  group('NearbyFacilityChip accessibility and layout', () {
    testWidgets('announces category and distance as one button', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(NearbyFacilityChip(facility: _facility())));
      expect(find.bySemanticsLabel('Mall, 600m from TRM Mall'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('tap target is at least 44px tall', (tester) async {
      await tester.pumpWidget(_host(NearbyFacilityChip(facility: _facility())));
      expect(tester.getSize(find.byType(NearbyFacilityChip)).height, greaterThanOrEqualTo(44));
    });

    testWidgets('a very long name wraps instead of overflowing', (tester) async {
      await tester.pumpWidget(_host(
        NearbyFacilityChip(
          facility: _facility(
            name: 'The Very Long Named Regional Referral and Teaching Hospital of Nairobi West',
            category: 'hospital',
          ),
        ),
        width: 200,
      ));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(NearbyFacilityChip)).width, lessThanOrEqualTo(200));
    });
  });
}
