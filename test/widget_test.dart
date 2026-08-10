import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:roost_app/main.dart';
import 'package:roost_app/widgets/common/roost_logo_icon.dart';

void main() {
  testWidgets('MyApp smoke test — renders splash logo', (WidgetTester tester) async {
    // SplashPage's async init chain (CountryService.init, AuthService's
    // token check) reads through SharedPreferences -- without mocked
    // initial values, that hits a real platform channel and throws
    // MissingPluginException in the test environment.
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());

    // First frame: SplashPage renders immediately -- its content
    // matches the native splash exactly (see splash_page.dart) so
    // there's no visible seam if the native view is ever briefly gone
    // by the time Flutter paints.
    expect(find.byType(RoostLogoIcon), findsOneWidget);

    // SplashPage holds for a 2.8s minimum (_minimumDisplay) before
    // calling FlutterNativeSplash.remove() and navigating -- drain that
    // timer instead of leaving it pending (flutter_test fails a test
    // that completes with an outstanding Timer), then pump a few more
    // fixed frames for the pushReplacement transition. Pump slightly
    // longer than the actual minimum (3.5s vs 2.8s) for safety margin.
    // FlutterNativeSplash.remove() itself is wrapped in try/catch in
    // production code specifically so it can't throw here (no real
    // native splash view exists in the widget test harness).
    //
    // Deliberately NOT pumpAndSettle(): whatever Splash navigates to
    // next (OnboardingPage) shows an indeterminate
    // CircularProgressIndicator while its own async location detection
    // runs, and an indeterminate spinner's AnimationController keeps
    // scheduling frames on its own -- pumpAndSettle loops until nothing
    // is scheduled, which that never satisfies by itself, causing a
    // timeout unrelated to anything this test is actually checking.
    await tester.pump(const Duration(milliseconds: 3500));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  });
}
