import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/widgets/auth/apple_sign_in_button.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('shows the label and fires onPressed on iOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var taps = 0;

    await tester.pumpWidget(_host(AppleSignInButton(onPressed: () => taps++)));

    expect(find.text('Continue with Apple'), findsOneWidget);
    await tester.tap(find.byType(ElevatedButton));
    expect(taps, 1);
  });

  testWidgets('is disabled when onPressed is null', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    await tester.pumpWidget(_host(const AppleSignInButton(onPressed: null)));

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('renders nothing on Android', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    await tester.pumpWidget(_host(AppleSignInButton(onPressed: () {})));

    expect(find.text('Continue with Apple'), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
  });
}
