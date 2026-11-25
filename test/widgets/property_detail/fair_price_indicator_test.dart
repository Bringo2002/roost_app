import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roost_app/models/property.dart';
import 'package:roost_app/widgets/property_detail/fair_price_indicator.dart';

Property _property({double? average = 50000, int? sampleSize = 12, double? percentDiff = -20}) {
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
    priceComparisonAverage: average,
    priceComparisonSampleSize: sampleSize,
    priceComparisonPercentDiff: percentDiff,
  );
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Tapping fires a haptic; give the platform channel a no-op handler.
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('FairPriceIndicator label', () {
    testWidgets('says how far below similar listings the price is', (tester) async {
      await tester.pumpWidget(_wrap(FairPriceIndicator(property: _property(percentDiff: -20))));

      expect(find.text('20% below similar listings nearby'), findsOneWidget);
    });

    testWidgets('says how far above similar listings the price is', (tester) async {
      await tester.pumpWidget(_wrap(FairPriceIndicator(property: _property(percentDiff: 30))));

      expect(find.text('30% above similar listings nearby'), findsOneWidget);
    });

    testWidgets('says in line inside the neutral band', (tester) async {
      await tester.pumpWidget(_wrap(FairPriceIndicator(property: _property(percentDiff: 5))));

      expect(find.text('In line with similar listings nearby'), findsOneWidget);
    });

    testWidgets('renders nothing without comparison data', (tester) async {
      await tester.pumpWidget(_wrap(FairPriceIndicator(property: _property(percentDiff: null))));

      expect(find.textContaining('similar listings'), findsNothing);
      expect(find.text('Cheaper'), findsNothing);
    });
  });

  group('FairPriceIndicator accessibility', () {
    testWidgets('is one button announcing the same sentence a sighted user reads', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(FairPriceIndicator(property: _property(percentDiff: -20))));

      expect(
        tester.getSemantics(find.bySemanticsLabel('20% below similar listings nearby')),
        isSemantics(label: '20% below similar listings nearby', isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('the gradient bar end labels are still drawn but not read out as separate stops', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(FairPriceIndicator(property: _property(percentDiff: -20))));

      expect(find.text('Cheaper'), findsOneWidget);
      expect(find.text('More expensive'), findsOneWidget);
      expect(find.bySemanticsLabel('Cheaper'), findsNothing);
      expect(find.bySemanticsLabel('More expensive'), findsNothing);
      handle.dispose();
    });

    testWidgets('activating it through semantics shows how the comparison was made', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(FairPriceIndicator(property: _property(percentDiff: -20))));

      tester.semantics.tap(find.semantics.byLabel('20% below similar listings nearby'));
      await tester.pump();

      expect(find.text('Based on 12 similar listings nearby. Average rent: 50000.'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a real tap shows it too', (tester) async {
      await tester.pumpWidget(_wrap(FairPriceIndicator(property: _property(percentDiff: -20))));

      await tester.tap(find.text('20% below similar listings nearby'));
      await tester.pump();

      expect(find.text('Based on 12 similar listings nearby. Average rent: 50000.'), findsOneWidget);
    });
  });
}
