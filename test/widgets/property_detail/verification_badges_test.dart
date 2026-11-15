import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roost_app/models/property.dart';
import 'package:roost_app/widgets/property_detail/verification_badges.dart';

Property _property({bool verified = false, int documentCount = 0}) {
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
    verified: verified,
    documentCount: documentCount,
    riskFlags: const [],
    imageUrls: const [],
    bathrooms: 1,
    managerRole: 'LANDLORD',
  );
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('VerificationBadges document badge', () {
    testWidgets('shows Doc Attached when documents were submitted', (tester) async {
      await tester.pumpWidget(
        _wrap(VerificationBadges(property: _property(documentCount: 1))),
      );

      expect(find.text('Doc Attached'), findsOneWidget);
    });

    testWidgets('hides Doc Attached when no documents were submitted', (tester) async {
      await tester.pumpWidget(_wrap(VerificationBadges(property: _property())));

      expect(find.text('Doc Attached'), findsNothing);
    });

    testWidgets('a fully verified listing shows Verified Listing instead', (tester) async {
      await tester.pumpWidget(
        _wrap(VerificationBadges(property: _property(verified: true, documentCount: 1))),
      );

      expect(find.text('Verified Listing'), findsOneWidget);
      expect(find.text('Doc Attached'), findsNothing);
    });
  });
}
