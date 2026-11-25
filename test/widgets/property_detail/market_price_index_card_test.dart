import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roost_app/l10n/generated/app_localizations.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/rent_estimator_service.dart';
import 'package:roost_app/widgets/property_detail/market_price_index_card.dart';

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
    verified: false,
    documentCount: 0,
    riskFlags: const [],
    imageUrls: const [],
    bathrooms: 1,
    managerRole: 'LANDLORD',
  );
}

RentEstimate _estimate({
  double percentile = 0.73,
  MarketRating rating = MarketRating.greatDeal,
  List<ValueDriver> drivers = const [
    ValueDriver(label: 'Parking', impact: '+5-10%', isPositive: true),
    ValueDriver(label: 'Missing Water Tank', impact: '-5-8%', isPositive: false),
  ],
}) {
  return RentEstimate(
    minPrice: 30000,
    medianPrice: 45000,
    maxPrice: 70000,
    rating: rating,
    percentile: percentile,
    valueDrivers: drivers,
    comparableCount: 18,
  );
}

Future<void> _pumpCard(
  WidgetTester tester, {
  RentEstimate? estimate,
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: MarketPriceIndexCard(property: _property(), estimator: (_) async => estimate),
        ),
      ),
    ),
  );
  // Resolves the stubbed estimate, then lets the 900ms gauge animation finish.
  await tester.pumpAndSettle();
}

void main() {
  group('MarketPriceIndexCard headings', () {
    testWidgets('the card title and the value drivers title are headings', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpCard(tester, estimate: _estimate());

      expect(
        tester.getSemantics(find.bySemanticsLabel('Market Price Analysis')),
        isSemantics(label: 'Market Price Analysis', isHeader: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('VALUE DRIVERS')),
        isSemantics(label: 'VALUE DRIVERS', isHeader: true),
      );
      handle.dispose();
    });

    testWidgets('the title is a heading in the not-enough-data state too', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpCard(tester, estimate: null);

      expect(
        tester.getSemantics(find.bySemanticsLabel('Market Price Analysis')),
        isSemantics(label: 'Market Price Analysis', isHeader: true),
      );
      handle.dispose();
    });
  });

  group('MarketPriceIndexCard rating', () {
    testWidgets('the decorative emoji is not announced, the rating label is', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpCard(tester, estimate: _estimate(rating: MarketRating.greatDeal));

      expect(find.text('🔥'), findsOneWidget);
      expect(find.bySemanticsLabel('🔥'), findsNothing);
      expect(find.bySemanticsLabel('Great Deal'), findsOneWidget);
      handle.dispose();
    });
  });

  group('MarketPriceIndexCard price gauge', () {
    testWidgets('is one sentence saying how many comparable listings are priced at or below this one', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpCard(tester, estimate: _estimate(percentile: 0.73));

      expect(
        find.bySemanticsLabel('Price position: 73% of comparable listings are priced at or below this one.'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('its pin text and end labels are drawn but not read out as separate stops', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpCard(tester, estimate: _estimate(percentile: 0.73));

      expect(find.text('Lower'), findsOneWidget);
      expect(find.text('Neighborhood Average'), findsOneWidget);
      expect(find.text('Higher'), findsOneWidget);
      expect(find.bySemanticsLabel('Lower'), findsNothing);
      expect(find.bySemanticsLabel('Neighborhood Average'), findsNothing);
      expect(find.bySemanticsLabel('Higher'), findsNothing);
      expect(find.bySemanticsLabel('PRICE POSITION'), findsNothing);
      handle.dispose();
    });

    testWidgets('is localized to Swahili', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpCard(tester, estimate: _estimate(percentile: 0.73), locale: const Locale('sw'));

      expect(
        find.bySemanticsLabel('Nafasi ya bei: asilimia 73 ya mali zinazofanana zina bei sawa au chini ya hii.'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('MarketPriceIndexCard stat chips and drivers', () {
    testWidgets('each stat chip reads its label and value as one item', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpCard(tester, estimate: _estimate());

      expect(find.bySemanticsLabel(RegExp(r'^Low\s+.*30,000$')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Median\s+.*45,000$')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^High\s+.*70,000$')), findsOneWidget);
      // The bare words are no longer stops of their own.
      expect(find.bySemanticsLabel('Low'), findsNothing);
      expect(find.bySemanticsLabel('Median'), findsNothing);
      expect(find.bySemanticsLabel('High'), findsNothing);
      handle.dispose();
    });

    testWidgets('each value driver reads its label and signed impact as one item', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpCard(tester, estimate: _estimate());

      expect(find.bySemanticsLabel(RegExp(r'^Parking\s+\+5-10%$')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Missing Water Tank\s+-5-8%$')), findsOneWidget);
      expect(find.bySemanticsLabel('Parking'), findsNothing);
      expect(find.bySemanticsLabel('+5-10%'), findsNothing);
      handle.dispose();
    });

    testWidgets('no value drivers section when there are none', (tester) async {
      await _pumpCard(tester, estimate: _estimate(drivers: const []));

      expect(find.text('VALUE DRIVERS'), findsNothing);
    });
  });
}
