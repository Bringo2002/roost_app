import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roost_app/l10n/generated/app_localizations.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/models/user.dart';
import 'package:roost_app/widgets/property_detail/trust_verification_card.dart';

Property _property({
  User? owner,
  bool verified = true,
  bool gpsVerified = false,
  bool documentVerified = false,
}) {
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
    gpsVerified: gpsVerified,
    documentVerified: documentVerified,
    riskFlags: const [],
    imageUrls: const [],
    bathrooms: 1,
    managerRole: 'LANDLORD',
    owner: owner,
  );
}

Widget _wrap(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('TrustVerificationCard host avatar', () {
    testWidgets(
      'caps only one cache dimension so a non-square photo keeps its aspect ratio',
      (tester) async {
        final owner = User(
          id: 1,
          name: 'Brian H',
          email: 'brian@example.com',
          role: 'LANDLORD',
          avatarUrl: 'https://example.com/avatar.jpg',
        );

        await tester.pumpWidget(
          _wrap(TrustVerificationCard(property: _property(owner: owner))),
        );

        final image = tester.widget<CachedNetworkImage>(
          find.byType(CachedNetworkImage),
        );
        expect(image.memCacheWidth, isNotNull);
        expect(
          image.memCacheHeight,
          isNull,
          reason: 'Setting both memCacheWidth and memCacheHeight decodes the '
              'photo to an exact square and distorts it.',
        );
      },
    );

    testWidgets('shows the letter fallback and no network image without a photo', (
      tester,
    ) async {
      final owner = User(
        id: 1,
        name: 'Brian H',
        email: 'brian@example.com',
        role: 'LANDLORD',
      );

      await tester.pumpWidget(
        _wrap(TrustVerificationCard(property: _property(owner: owner))),
      );

      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(find.text('B'), findsOneWidget);
    });
  });

  group('TrustVerificationCard checkpoint semantics', () {
    testWidgets('a fully verified listing reads every checkpoint as verified', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(TrustVerificationCard(property: _property())));

      for (final label in const [
        'Phone SMS, Verified',
        'GPS Location, Verified',
        'Doc Proof, Verified',
      ]) {
        expect(
          tester.getSemantics(find.bySemanticsLabel(label)),
          containsSemantics(label: label, isButton: true, hasTapAction: true),
        );
      }
      handle.dispose();
    });

    testWidgets('an unverified listing reads GPS and document proof as pending', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(TrustVerificationCard(property: _property(verified: false))),
      );

      // Phone is always shown as verified; the other two follow the listing.
      expect(find.bySemanticsLabel('Phone SMS, Verified'), findsOneWidget);
      expect(find.bySemanticsLabel('GPS Location, Pending'), findsOneWidget);
      expect(find.bySemanticsLabel('Doc Proof, Pending'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('each checkpoint follows its own flag', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          TrustVerificationCard(
            property: _property(verified: false, gpsVerified: true),
          ),
        ),
      );

      expect(find.bySemanticsLabel('GPS Location, Verified'), findsOneWidget);
      expect(find.bySemanticsLabel('Doc Proof, Pending'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the state words are localized to Swahili', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          TrustVerificationCard(property: _property(verified: false)),
          locale: const Locale('sw'),
        ),
      );

      expect(find.bySemanticsLabel('Phone SMS, Imethibitishwa'), findsOneWidget);
      expect(find.bySemanticsLabel('GPS Location, Inasubiri'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a checkpoint opens the details sheet, whose rows spell out the state', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(TrustVerificationCard(property: _property(verified: false))),
      );

      tester.semantics.tap(find.semantics.byLabel('GPS Location, Pending'));
      await tester.pumpAndSettle();

      expect(find.text('Roost Trust & Verification Proof'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'^On-Site GPS Location, Pending\.')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'^Phone Authenticated, Verified\.')),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
