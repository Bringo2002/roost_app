import 'package:flutter/material.dart';
import 'package:roost_app/widgets/auth/google_logo.dart';

/// "Continue with Google" button for the auth pages, in Google's dark-theme
/// brand style: #131314 fill, #8E918F outline, #E3E3E3 label and the
/// four-colour G.
///
/// Sized like [AppleSignInButton] (full width, 56 tall, 16 radius) so the two
/// stack evenly. A null [onPressed] shows it disabled (for example while
/// another sign-in is in flight).
class GoogleSignInButton extends StatelessWidget {
  /// Creates the button.
  const GoogleSignInButton({super.key, required this.onPressed});

  /// Called when the button is tapped; null disables it.
  final VoidCallback? onPressed;

  static const _fill = Color(0xFF131314);
  static const _outline = Color(0xFF8E918F);
  static const _label = Color(0xFFE3E3E3);

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: _fill,
          disabledBackgroundColor: _fill,
          foregroundColor: _label,
          disabledForegroundColor: _label.withValues(alpha: 0.5),
          side: BorderSide(
            color: enabled ? _outline : _outline.withValues(alpha: 0.5),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: enabled ? 1 : 0.5,
              child: const GoogleLogo(),
            ),
            const SizedBox(width: 12),
            const Text(
              'Continue with Google',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
