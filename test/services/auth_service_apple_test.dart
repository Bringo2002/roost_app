import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/services/auth_service.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('AuthService.isAppleSignInAvailable', () {
    test('true on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(AuthService.isAppleSignInAvailable, isTrue);
    });

    test('false on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(AuthService.isAppleSignInAvailable, isFalse);
    });
  });

  test('signInWithApple fails cleanly (no Firebase call) when unavailable',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    final result = await AuthService.signInWithApple();

    expect(result.success, isFalse);
    expect(result.error, isNotNull);
    expect(result.isNewUser, isFalse);
  });
}
