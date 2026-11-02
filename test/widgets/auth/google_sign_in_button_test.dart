import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roost_app/widgets/auth/google_logo.dart';
import 'package:roost_app/widgets/auth/google_sign_in_button.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(24), child: child),
    ),
  );
}

void main() {
  group('GoogleSignInButton', () {
    testWidgets('shows the label and the Google logo', (tester) async {
      await tester.pumpWidget(
        _host(GoogleSignInButton(onPressed: () {})),
      );

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.byType(GoogleLogo), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(GoogleSignInButton(onPressed: () => taps++)),
      );

      await tester.tap(find.byType(GoogleSignInButton));

      expect(taps, 1);
    });

    testWidgets('is disabled when onPressed is null', (tester) async {
      await tester.pumpWidget(
        _host(const GoogleSignInButton(onPressed: null)),
      );

      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));

      expect(button.onPressed, isNull);
    });

    testWidgets('is full width and 56 tall, matching the Apple button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(GoogleSignInButton(onPressed: () {})),
      );

      final size = tester.getSize(find.byType(GoogleSignInButton));

      expect(size.height, 56);
      expect(size.width, 800 - 48);
    });

    testWidgets('uses the Google dark-theme fill and outline', (tester) async {
      await tester.pumpWidget(
        _host(GoogleSignInButton(onPressed: () {})),
      );

      final style =
          tester.widget<OutlinedButton>(find.byType(OutlinedButton)).style!;

      expect(style.backgroundColor!.resolve({}), const Color(0xFF131314));
      expect(style.side!.resolve({})!.color, const Color(0xFF8E918F));
    });

    testWidgets('announces itself to screen readers by its label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(GoogleSignInButton(onPressed: () {})),
      );

      expect(find.bySemanticsLabel('Continue with Google'), findsOneWidget);

      handle.dispose();
    });
  });
}
