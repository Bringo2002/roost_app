import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the Android Auto Backup opt-out.
///
/// With backup enabled, a reinstall restores the previous install's
/// SharedPreferences (including the onboarding-completed flag) while the
/// Keystore-backed auth token cannot be restored. The app then skips
/// onboarding and lands on the Welcome page, so a brand-new account goes
/// straight to the feed.
void main() {
  test('AndroidManifest opts out of Auto Backup', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final application = RegExp(r'<application\b[^>]*>').firstMatch(manifest);

    expect(application, isNotNull, reason: 'No <application> tag found');
    expect(application!.group(0), contains('android:allowBackup="false"'));
  });
}
