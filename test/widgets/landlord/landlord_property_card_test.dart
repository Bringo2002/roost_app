import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/widgets/landlord/landlord_property_card.dart';

/// Minimal, valid [Property] for card rendering, with only the fields
/// each test cares about overridden.
Property _property({
  int id = 1,
  String status = 'PUBLISHED',
  bool available = true,
  bool gpsVerified = false,
  String managerRole = 'LANDLORD',
  bool landlordEndorsed = false,
  String? listedAt,
}) {
  return Property(
    id: id,
    title: 'Cozy Bedsitter',
    description: 'A nice place',
    location: 'Kilimani, Nairobi',
    price: 25000,
    bedrooms: 1,
    type: 'RENTAL',
    landlordPhone: '+254700000000',
    available: available,
    status: status,
    gpsVerified: gpsVerified,
    managerRole: managerRole,
    landlordEndorsed: landlordEndorsed,
    listedAt: listedAt,
  );
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// All callbacks default to no-ops; each test overrides only the ones
/// it's asserting on, keeping the boilerplate below out of every test.
Widget _card({
  required Property property,
  bool isBusy = false,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
  ValueChanged<bool>? onToggleAvailability,
  VoidCallback? onPublish,
  VoidCallback? onViewApplications,
  VoidCallback? onVerifyGps,
  VoidCallback? onShareEndorsement,
  VoidCallback? onViewEndorsementBadge,
}) {
  return _wrap(LandlordPropertyCard(
    property: property,
    isBusy: isBusy,
    onEdit: onEdit ?? () {},
    onDelete: onDelete ?? () {},
    onToggleAvailability: onToggleAvailability ?? (_) {},
    onPublish: onPublish ?? () {},
    onViewApplications: onViewApplications ?? () {},
    onVerifyGps: onVerifyGps ?? () {},
    onShareEndorsement: onShareEndorsement ?? () {},
    onViewEndorsementBadge: onViewEndorsementBadge ?? () {},
  ));
}

void main() {
  group('LandlordPropertyCard', () {
    testWidgets('draft listing shows DRAFT badge + Publish, not Applications', (tester) async {
      var published = false;
      await tester.pumpWidget(_card(
        property: _property(status: 'DRAFT'),
        onPublish: () => published = true,
      ));

      expect(find.text('DRAFT'), findsOneWidget);
      expect(find.text('Not published yet'), findsOneWidget);
      expect(find.text('Publish'), findsOneWidget);
      expect(find.text('Applications'), findsNothing);

      await tester.tap(find.text('Publish'));
      await tester.pump();
      expect(published, isTrue);
    });

    testWidgets('published listing shows Applications, not Publish', (tester) async {
      await tester.pumpWidget(_card(property: _property(status: 'PUBLISHED')));

      expect(find.text('Applications'), findsOneWidget);
      expect(find.text('Publish'), findsNothing);
    });

    testWidgets('GPS verify pill shows when published and unverified, and calls onVerifyGps', (tester) async {
      var verifyTapped = false;
      await tester.pumpWidget(_card(
        property: _property(status: 'PUBLISHED', gpsVerified: false),
        onVerifyGps: () => verifyTapped = true,
      ));

      const pillText = 'Stand at property & tap to verify GPS location';
      expect(find.text(pillText), findsOneWidget);

      await tester.tap(find.text(pillText));
      await tester.pump();
      expect(verifyTapped, isTrue);
    });

    testWidgets('GPS verify pill is hidden once verified, badge reads VERIFIED', (tester) async {
      await tester.pumpWidget(_card(property: _property(status: 'PUBLISHED', gpsVerified: true)));

      expect(find.text('Stand at property & tap to verify GPS location'), findsNothing);
      expect(find.text('VERIFIED'), findsOneWidget);
    });

    testWidgets('caretaker-managed, not yet endorsed: shows pending pill + Send Link', (tester) async {
      var shared = false;
      await tester.pumpWidget(_card(
        property: _property(managerRole: 'CARETAKER', landlordEndorsed: false),
        onShareEndorsement: () => shared = true,
      ));

      expect(find.text('Pending Owner Endorsement'), findsOneWidget);
      expect(find.text('Send Link'), findsOneWidget);

      await tester.tap(find.text('Send Link'));
      await tester.pump();
      expect(shared, isTrue);
    });

    testWidgets('caretaker-managed, endorsed: shows endorsed pill + View Badge', (tester) async {
      var viewedBadge = false;
      await tester.pumpWidget(_card(
        property: _property(managerRole: 'CARETAKER', landlordEndorsed: true),
        onViewEndorsementBadge: () => viewedBadge = true,
      ));

      expect(find.text('Landlord Endorsed Listing'), findsOneWidget);
      expect(find.text('View Badge'), findsOneWidget);

      await tester.tap(find.text('View Badge'));
      await tester.pump();
      expect(viewedBadge, isTrue);
    });

    testWidgets('direct landlord listing has no endorsement pill at all', (tester) async {
      await tester.pumpWidget(_card(property: _property(managerRole: 'LANDLORD')));

      expect(find.text('Pending Owner Endorsement'), findsNothing);
      expect(find.text('Landlord Endorsed Listing'), findsNothing);
    });

    testWidgets('availability switch reflects state and reports the new value', (tester) async {
      bool? toggledTo;
      await tester.pumpWidget(_card(
        property: _property(available: true),
        onToggleAvailability: (v) => toggledTo = v,
      ));

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      expect(tester.widget<Switch>(switchFinder).value, isTrue);

      await tester.tap(switchFinder);
      await tester.pump();
      expect(toggledTo, isFalse);
    });

    testWidgets('edit and delete icons call their callbacks', (tester) async {
      var edited = false;
      var deleted = false;
      await tester.pumpWidget(_card(
        property: _property(),
        onEdit: () => edited = true,
        onDelete: () => deleted = true,
      ));

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pump();
      expect(edited, isTrue);

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pump();
      expect(deleted, isTrue);
    });

    testWidgets('delete button and switch are disabled while busy', (tester) async {
      var deleted = false;
      await tester.pumpWidget(_card(
        property: _property(),
        isBusy: true,
        onDelete: () => deleted = true,
      ));

      final deleteButton = tester.widget<IconButton>(find.ancestor(
        of: find.byIcon(Icons.delete_outline_rounded),
        matching: find.byType(IconButton),
      ));
      expect(deleteButton.onPressed, isNull);

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pump();
      expect(deleted, isFalse);

      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    });

    testWidgets('malformed listedAt does not throw and falls back to "Listed recently"', (tester) async {
      await tester.pumpWidget(_card(property: _property(listedAt: 'not-a-real-date')));

      expect(tester.takeException(), isNull);
      expect(find.text('Listed recently'), findsOneWidget);
    });

    testWidgets('valid listedAt renders a formatted date', (tester) async {
      await tester.pumpWidget(_card(property: _property(listedAt: '2026-03-14T00:00:00Z')));

      expect(find.text('Listed 14 Mar 2026'), findsOneWidget);
    });
  });
}
