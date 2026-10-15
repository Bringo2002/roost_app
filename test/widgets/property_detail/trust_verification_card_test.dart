import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roost_app/models/property.dart';
import 'package:roost_app/models/user.dart';
import 'package:roost_app/widgets/property_detail/trust_verification_card.dart';

Property _property({User? owner}) {
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
    verified: true,
    riskFlags: const [],
    imageUrls: const [],
    bathrooms: 1,
    managerRole: 'LANDLORD',
    owner: owner,
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
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
}
