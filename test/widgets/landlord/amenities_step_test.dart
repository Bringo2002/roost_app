import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roost_app/widgets/landlord/amenities_step.dart';
import 'package:roost_app/widgets/landlord/amenity_options.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The step fires haptics on tap; give the platform channel a no-op handler.
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  final toggles = <(String, bool)>[];
  final added = <String>[];
  final removed = <String>[];

  Future<void> pumpStep(
    WidgetTester tester, {
    Map<String, bool> selected = const {},
    List<String> custom = const [],
  }) async {
    toggles.clear();
    added.clear();
    removed.clear();
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: AmenitiesStep(
              selected: selected,
              customAmenities: custom,
              onToggle: (key, value) => toggles.add((key, value)),
              onAddCustom: added.add,
              onRemoveCustom: removed.add,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> tapAddCustom(WidgetTester tester) async {
    await tester.tap(find.text('Add Custom'));
    await tester.pumpAndSettle();
  }

  group('standard amenities', () {
    testWidgets('shows a tile for every option', (tester) async {
      await pumpStep(tester);

      for (final option in kAmenityOptions) {
        expect(find.text(option.label), findsOneWidget);
      }
    });

    testWidgets('marks only the selected amenities with a check', (
      tester,
    ) async {
      await pumpStep(tester, selected: {'wifi': true, 'pool': true});

      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
    });

    testWidgets('treats a missing key as off', (tester) async {
      await pumpStep(tester, selected: {'wifi': false});

      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    });

    testWidgets('tapping an off amenity reports it as on', (tester) async {
      await pumpStep(tester);

      await tester.tap(find.text('WiFi / Fiber'));

      expect(toggles, [('wifi', true)]);
    });

    testWidgets('tapping an on amenity reports it as off', (tester) async {
      await pumpStep(tester, selected: {'wifi': true});

      await tester.tap(find.text('WiFi / Fiber'));

      expect(toggles, [('wifi', false)]);
    });
  });

  group('custom amenities', () {
    testWidgets('shows an empty state when there are none', (tester) async {
      await pumpStep(tester);

      expect(find.text('No custom amenities added yet'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('lists each custom amenity instead of the empty state', (
      tester,
    ) async {
      await pumpStep(tester, custom: ['Sauna', 'EV Charger']);

      expect(find.text('Sauna'), findsOneWidget);
      expect(find.text('EV Charger'), findsOneWidget);
      expect(find.text('No custom amenities added yet'), findsNothing);
    });

    testWidgets('tapping a custom amenity close icon reports its name', (
      tester,
    ) async {
      await pumpStep(tester, custom: ['Sauna', 'EV Charger']);

      await tester.tap(find.byIcon(Icons.close_rounded).first);

      expect(removed, ['Sauna']);
    });
  });

  group('add custom amenity dialog', () {
    testWidgets('adds the trimmed name', (tester) async {
      await pumpStep(tester);
      await tapAddCustom(tester);

      expect(find.text('Add Custom Amenity'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '  Sauna  ');
      await tester.tap(find.text('Add Amenity'));
      await tester.pumpAndSettle();

      expect(added, ['Sauna']);
      expect(find.text('Add Custom Amenity'), findsNothing);
    });

    testWidgets('ignores a blank name', (tester) async {
      await pumpStep(tester);
      await tapAddCustom(tester);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('Add Amenity'));
      await tester.pumpAndSettle();

      expect(added, isEmpty);
      expect(find.text('Add Custom Amenity'), findsNothing);
    });

    testWidgets('ignores a name that is already listed', (tester) async {
      await pumpStep(tester, custom: ['Sauna']);
      await tapAddCustom(tester);

      await tester.enterText(find.byType(TextField), 'Sauna');
      await tester.tap(find.text('Add Amenity'));
      await tester.pumpAndSettle();

      expect(added, isEmpty);
    });

    testWidgets('cancel closes the dialog without adding', (tester) async {
      await pumpStep(tester);
      await tapAddCustom(tester);

      await tester.enterText(find.byType(TextField), 'Sauna');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(added, isEmpty);
      expect(find.text('Add Custom Amenity'), findsNothing);
    });
  });
}
