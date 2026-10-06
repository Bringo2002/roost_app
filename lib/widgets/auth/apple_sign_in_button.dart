import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:roost_app/services/auth_service.dart';

/// "Continue with Apple" button, sized to sit directly under the existing
/// "Continue with Google" button on the auth pages.
///
/// Renders nothing on platforms where Sign in with Apple isn't offered
/// (see [AuthService.isAppleSignInAvailable]), so callers can place it
/// unconditionally. White-on-dark follows Apple's button guidelines for
/// dark backgrounds. A null [onPressed] shows it disabled (e.g. while
/// another sign-in is in flight).
class AppleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const AppleSignInButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    if (!AuthService.isAppleSignInAvailable) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          disabledBackgroundColor: Colors.white24,
          disabledForegroundColor: Colors.black38,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: const Icon(Icons.apple, size: 22),
        label: const Text(
          'Continue with Apple',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
