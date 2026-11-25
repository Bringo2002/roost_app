import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roost_app/models/property.dart';
import 'package:roost_app/widgets/property_detail/verification_badges.dart';

Property _property({bool verified = false, bool communityVerified = false, int documentCount = 0}) {
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
    communityVerified: communityVerified,
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

  group('VerificationBadges accessibility', () {
    testWidgets('a tappable badge has a touch target of at least 44x44', (tester) async {
      await tester.pumpWidget(
        _wrap(VerificationBadges(property: _property(verified: true), onTapVerification: () {})),
      );

      // The only tappable thing in the row is the Verified Listing badge.
      final target = find.descendant(
        of: find.byType(VerificationBadges),
        matching: find.byType(GestureDetector),
      );
      expect(target, findsOneWidget);
      final size = tester.getSize(target);
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('the pill itself stays compact inside its 44px slot', (tester) async {
      await tester.pumpWidget(
        _wrap(VerificationBadges(property: _property(verified: true), onTapVerification: () {})),
      );

      final pill = find.ancestor(of: find.text('Verified Listing'), matching: find.byType(Container)).first;
      expect(tester.getSize(pill).height, lessThan(44));
    });

    testWidgets('a tappable badge is one button named by its text, and activating it opens the details', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var opened = 0;
      await tester.pumpWidget(
        _wrap(
          VerificationBadges(property: _property(verified: true), onTapVerification: () => opened++),
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Verified Listing')),
        isSemantics(label: 'Verified Listing', isButton: true, hasTapAction: true),
      );

      tester.semantics.tap(find.semantics.byLabel('Verified Listing'));
      expect(opened, 1);
      handle.dispose();
    });

    testWidgets('a real tap on the badge opens the details', (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        _wrap(
          VerificationBadges(property: _property(verified: true), onTapVerification: () => opened++),
        ),
      );

      await tester.tap(find.text('Verified Listing'));
      expect(opened, 1);
    });

    testWidgets('a tap in the slot but outside the pill still counts', (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        _wrap(
          VerificationBadges(property: _property(verified: true), onTapVerification: () => opened++),
        ),
      );

      final slot = find.descendant(
        of: find.byType(VerificationBadges),
        matching: find.byType(GestureDetector),
      );
      // 4px above the pill's top edge, inside the 44px slot's slack.
      final pillTop = tester.getTopLeft(find.text('Verified Listing')).dy;
      final slotTop = tester.getTopLeft(slot).dy;
      expect(slotTop, lessThan(pillTop));
      await tester.tapAt(Offset(tester.getCenter(slot).dx, slotTop + 2));
      expect(opened, 1);
    });

    testWidgets('without a callback a badge is plain text, not a button', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(VerificationBadges(property: _property(verified: true))));

      expect(
        tester.getSemantics(find.bySemanticsLabel('Verified Listing')),
        isSemantics(label: 'Verified Listing', isButton: false, hasTapAction: false),
      );
      handle.dispose();
    });

    testWidgets('Community Verified is informational: never a button, even with a callback', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          VerificationBadges(property: _property(communityVerified: true), onTapVerification: () {}),
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Community Verified')),
        isSemantics(label: 'Community Verified', isButton: false, hasTapAction: false),
      );
      handle.dispose();
    });

    testWidgets('the availability pill is plain text, not a button', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(VerificationBadges(property: _property(), onTapVerification: () {})));

      expect(
        tester.getSemantics(find.bySemanticsLabel('Available')),
        isSemantics(label: 'Available', isButton: false, hasTapAction: false),
      );
      handle.dispose();
    });
  });
}
