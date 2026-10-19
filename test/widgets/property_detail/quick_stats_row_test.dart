import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roost_app/l10n/generated/app_localizations.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/widgets/property_detail/quick_stats_row.dart';

Property _property({int bedrooms = 2, int bathrooms = 2}) {
  return Property(
    id: 1,
    title: 'Modern Apartments',
    description: 'A lovely place to call home.',
    location: 'Kilimani, Nairobi',
    price: 60000,
    bedrooms: bedrooms,
    type: 'RENTAL',
    landlordPhone: '+254712345678',
    available: true,
    bathrooms: bathrooms,
  );
}

Widget _host(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('QuickStatsRow semantics', () {
    testWidgets('reads each count-up card once, with its final value', (tester) async {
      final handle = tester.ensureSemantics();
      // First frame only: the visible numbers are still counting up from 0.
      await tester.pumpWidget(_host(QuickStatsRow(property: _property())));

      expect(find.bySemanticsLabel('2 beds, Bedrooms'), findsOneWidget);
      expect(find.bySemanticsLabel('2 Bath, Bathrooms'), findsOneWidget);
      // None of the in-between values are exposed.
      expect(find.bySemanticsLabel(RegExp(r'^[01] (beds?|Bath)')), findsNothing);
      handle.dispose();
    });

    testWidgets('the exposed label does not change as the number animates', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(QuickStatsRow(property: _property())));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.bySemanticsLabel('2 Bath, Bathrooms'), findsOneWidget);
      expect(find.text('2 Bath'), findsOneWidget);
      handle.dispose();
    });
  });
}
