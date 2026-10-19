import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roost_app/widgets/property_detail/section_header.dart';

Widget _host(Widget child) {
  return MaterialApp(home: Scaffold(body: Center(child: child)));
}

void main() {
  group('SectionHeader semantics', () {
    testWidgets('exposes its label as a heading', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const SectionHeader('Amenities')));

      expect(
        tester.getSemantics(find.bySemanticsLabel('Amenities')),
        containsSemantics(label: 'Amenities', isHeader: true),
      );
      expect(find.text('Amenities'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('keeps a trailing control a separate button, not part of the heading', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 360,
            child: SectionHeader(
              'Location & Surroundings',
              trailing: TextButton(onPressed: () {}, child: const Text('Fullscreen')),
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Location & Surroundings')),
        containsSemantics(isHeader: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Fullscreen')),
        containsSemantics(isButton: true, isHeader: false),
      );
      handle.dispose();
    });
  });
}
