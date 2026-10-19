import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/country_service.dart';
import 'package:roost_app/widgets/property_detail/move_in_cost_calculator_card.dart';

Property _property() {
  return Property(
    id: 1,
    title: 'Modern Apartments',
    description: 'A lovely place to call home.',
    location: 'Kilimani, Nairobi',
    price: 60000,
    bedrooms: 2,
    type: 'RENTAL',
    landlordPhone: '+254712345678',
    available: true,
  );
}

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('MoveInCostCalculatorCard semantics', () {
    testWidgets('announces the final total at once, while the figure is still animating', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final property = _property();
      final symbol = CountryService.config.currencySymbol;
      final total = NumberFormat('#,##0', 'en_US').format(property.totalInitialMoveInCost);

      // First frame only: the visible figure starts at 80% of the total and
      // animates up, but the exposed value must already be the final one.
      await tester.pumpWidget(_host(MoveInCostCalculatorCard(property: property)));

      expect(find.bySemanticsLabel('$symbol $total'), findsOneWidget);
      handle.dispose();
    });
  });
}
