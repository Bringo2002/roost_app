import 'package:flutter/material.dart';
import 'package:roost_app/services/api_service.dart';

/// Manages push notifications token registration and local message alerts for Roost.
class PushNotificationService {
  PushNotificationService._();

  static bool _initialized = false;
  static String? _fcmToken;

  /// Initializes notification channels and registers device token with Spring Boot backend.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // Mock FCM token generation for local dev & testing
      _fcmToken = 'roost_device_token_${DateTime.now().millisecondsSinceEpoch}';
      await registerTokenWithBackend(_fcmToken!);
    } catch (_) {}
  }

  /// Sends device FCM token to `/api/users/me/fcm-token`
  static Future<void> registerTokenWithBackend(String token) async {
    try {
      await ApiService.post('/api/users/me/fcm-token', {'fcmToken': token});
    } catch (_) {}
  }

  /// Displays an in-app banner for incoming chat or booking updates.
  static void showInAppNotification(BuildContext context, {required String title, required String body, VoidCallback? onTap}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1C1C1E),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white24, width: 1),
        ),
        content: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(body, style: TextStyle(color: Colors.grey[400], fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        action: onTap != null
            ? SnackBarAction(
                label: 'VIEW',
                textColor: Colors.white,
                onPressed: onTap,
              )
            : null,
      ),
    );
  }
}
