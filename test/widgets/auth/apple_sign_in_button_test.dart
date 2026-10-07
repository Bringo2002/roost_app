import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/widgets/auth/apple_sign_in_button.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  // The platform is set with TargetPlatformVariant rather than by assigning
  // debugDefaultTargetPlatformOverride: flutter_test asserts that override is
  // unset when the test body ends, which is before any tearDown() runs, so a
  // manual reset in tearDown still fails the test.
  testWidgets('shows the label and fires onPressed on iOS', (tester) async {
    var taps = 0;

    await tester.pumpWidget(_host(AppleSignInButton(onPressed: () => taps++)));

    expect(find.text('Continue with Apple'), findsOneWidget);
    await tester.tap(find.byType(ElevatedButton));
    expect(taps, 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('is disabled when onPressed is null', (tester) async {
    await tester.pumpWidget(_host(const AppleSignInButton(onPressed: null)));

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('renders nothing on Android', (tester) async {
    await tester.pumpWidget(_host(AppleSignInButton(onPressed: () {})));

    expect(find.text('Continue with Apple'), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
