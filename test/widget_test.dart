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

    // SplashPage holds for 3s before navigating on -- drain that timer
    // instead of leaving it pending (flutter_test fails a test that
    // completes with an outstanding Timer), then pump a few more fixed
    // frames to let the pushReplacement transition run. Pump slightly
    // longer than the actual delay (4s vs 3s) for safety margin, rather
    // than pumping the exact boundary value.
    //
    // Deliberately NOT pumpAndSettle() here: whatever Splash navigates
    // to next (OnboardingPage) shows an indeterminate
    // CircularProgressIndicator while its own async location detection
    // runs, and an indeterminate spinner's AnimationController keeps
    // scheduling frames on its own -- pumpAndSettle loops until nothing
    // is scheduled, which that never satisfies by itself, causing a
    // timeout unrelated to anything this test is actually checking.
    await tester.pump(const Duration(seconds: 4));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  });
}
