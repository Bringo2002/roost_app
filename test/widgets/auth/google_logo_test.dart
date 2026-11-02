import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roost_app/widgets/auth/google_logo.dart';

Widget _host(Widget child) {
  return MaterialApp(home: Scaffold(body: Center(child: child)));
}

void main() {
  group('GoogleLogo', () {
    testWidgets('is 20 logical pixels square by default', (tester) async {
      await tester.pumpWidget(_host(const GoogleLogo()));

      expect(tester.getSize(find.byType(GoogleLogo)), const Size(20, 20));
    });

    testWidgets('honors a custom size', (tester) async {
      await tester.pumpWidget(_host(const GoogleLogo(size: 32)));

      expect(tester.getSize(find.byType(GoogleLogo)), const Size(32, 32));
    });

    testWidgets('paints the four brand colors in order', (tester) async {
      await tester.pumpWidget(_host(const GoogleLogo()));

      final paint = tester.renderObject(
        find
            .descendant(
              of: find.byType(GoogleLogo),
              matching: find.byType(CustomPaint),
            )
            .first,
      );

      expect(
        paint,
        paints
          ..path(color: const Color(0xFF4285F4))
          ..path(color: const Color(0xFF34A853))
          ..path(color: const Color(0xFFFBBC05))
          ..path(color: const Color(0xFFEA4335)),
      );
    });

    testWidgets('is decorative and hidden from semantics', (tester) async {
      await tester.pumpWidget(_host(const GoogleLogo()));

      expect(
        find.descendant(
          of: find.byType(GoogleLogo),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
    });
  });
}
