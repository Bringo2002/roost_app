import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:roost_app/main.dart';

void main() {
  testWidgets('MyApp smoke test — renders splash title', (WidgetTester tester) async {
    // SplashPage's async init chain (CountryService.init, AuthService's
    // token check) reads through SharedPreferences -- without mocked
    // initial values, that hits a real platform channel and throws
    // MissingPluginException in the test environment.
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());

    // First frame: SplashPage's static branding renders immediately,
    // before any of its async auth/onboarding checks resolve. This is
    // the app's actual on-screen title -- MaterialApp.title ('Roost',
    // used for the OS task switcher) is never rendered in the UI, which
    // is what the original assertion here was actually checking for.
    expect(find.text('ROOST'), findsOneWidget);

    // SplashPage holds for 2s before navigating on. Drain that timer
    // instead of leaving it pending -- flutter_test fails a test that
    // completes with an outstanding Timer -- then let the rest of the
    // async chain and whatever it navigates to settle.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
