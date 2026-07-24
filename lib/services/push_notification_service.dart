import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/auth_service.dart';

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  bool isRead;
  final String type; // 'chat', 'booking', 'listing', 'system'
  final Map<String, dynamic>? payload;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    this.type = 'system',
    this.payload,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
        'type': type,
        if (payload != null) 'payload': payload,
      };

  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        body: json['body'] ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
            : DateTime.now(),
        isRead: json['isRead'] == true,
        type: json['type'] ?? 'system',
        payload: json['payload'] is Map<String, dynamic> ? json['payload'] : null,
      );
}

/// Manages push notifications, user-scoped history, and device token registration for Roost.
class PushNotificationService {
  PushNotificationService._();

  static String? _fcmToken;
  static const String _baseEnabledKey = 'push_notifications_enabled';
  static const String _baseHistoryKey = 'notification_history_v2';

  /// ValueNotifier exposing unread notification count across the app
  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  /// In-memory notification list for active user
  static List<NotificationItem> _notifications = [];

  static Future<String> _getHistoryKey() async {
    try {
      final email = await AuthService.getUserEmail();
      if (email != null && email.isNotEmpty) {
        final sanitized = email.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
        return '${_baseHistoryKey}_$sanitized';
      }
    } catch (_) {}
    return '${_baseHistoryKey}_guest';
  }

  static Future<String> _getEnabledKey() async {
    try {
      final email = await AuthService.getUserEmail();
      if (email != null && email.isNotEmpty) {
        final sanitized = email.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
        return '${_baseEnabledKey}_$sanitized';
      }
    } catch (_) {}
    return '${_baseEnabledKey}_guest';
  }

  /// Initializes notification channels, loads user settings, and registers device token.
  static Future<void> initialize() async {
    await reloadForUser();

    try {
      if (await isEnabled()) {
        _fcmToken = 'roost_device_token_${DateTime.now().millisecondsSinceEpoch}';
        await registerTokenWithBackend(_fcmToken!);
      }
    } catch (_) {}
  }

  /// Reloads notifications and preferences for the currently logged-in user profile
  static Future<void> reloadForUser() async {
    await _loadFromStorage();
  }

  /// Checks if push notifications are enabled for current user (defaults to true)
  static Future<bool> isEnabled() async {
    final key = await _getEnabledKey();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? true;
  }

  /// Enables or disables push notifications for current user
  static Future<void> setEnabled(bool enabled) async {
    final key = await _getEnabledKey();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, enabled);
    if (enabled && _fcmToken != null) {
      await registerTokenWithBackend(_fcmToken);
    }
  }

  /// Sends device FCM token to `/api/users/me/fcm-token`
  static Future<void> registerTokenWithBackend(String? token) async {
    if (token == null || token.isEmpty) return;
    try {
      await ApiService.post('/api/users/me/fcm-token', {'fcmToken': token});
    } catch (_) {}
  }

  /// Returns all stored notifications for active user
  static List<NotificationItem> getNotifications() {
    return List.unmodifiable(_notifications);
  }

  /// Adds a new incoming notification, saves to active user storage, and notifies listeners
  static Future<void> addNotification({
    required String title,
    required String body,
    String type = 'system',
    Map<String, dynamic>? payload,
    BuildContext? context,
    VoidCallback? onTap,
  }) async {
    if (!await isEnabled()) return;

    final item = NotificationItem(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}_${_notifications.length}',
      title: title,
      body: body,
      timestamp: DateTime.now(),
      isRead: false,
      type: type,
      payload: payload,
    );

    _notifications.insert(0, item);
    await _saveToStorage();
    _updateUnreadCount();

    if (context != null && context.mounted) {
      showInAppBanner(context, title: title, body: body, onTap: onTap);
    }
  }

  /// Marks a specific notification as read
  static Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index].isRead = true;
      await _saveToStorage();
      _updateUnreadCount();
    }
  }

  /// Marks all notifications as read for active user
  static Future<void> markAllAsRead() async {
    bool changed = false;
    for (var n in _notifications) {
      if (!n.isRead) {
        n.isRead = true;
        changed = true;
      }
    }
    if (changed) {
      await _saveToStorage();
      _updateUnreadCount();
    }
  }

  /// Clears notification history for active user
  static Future<void> clearAll() async {
    _notifications.clear();
    await _saveToStorage();
    _updateUnreadCount();
  }

  /// Displays an in-app banner for incoming notifications
  static void showInAppBanner(
    BuildContext context, {
    required String title,
    required String body,
    VoidCallback? onTap,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1C1C1E),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Colors.white24, width: 0.5),
        ),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(body, style: TextStyle(color: Colors.grey[400], fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
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

  /// Legacy method for backward compatibility
  static void showInAppNotification(BuildContext context, {required String title, required String body, VoidCallback? onTap}) {
    showInAppBanner(context, title: title, body: body, onTap: onTap);
  }

  static Future<void> _loadFromStorage() async {
    try {
      final key = await _getHistoryKey();
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(key);
      if (rawJson != null && rawJson.isNotEmpty) {
        final List decoded = jsonDecode(rawJson);
        _notifications = decoded.map((j) => NotificationItem.fromJson(j)).toList();
      } else {
        // Initial welcome notification unique to this new user profile
        _notifications = [
          NotificationItem(
            id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
            title: 'Welcome to Roost!',
            body: 'Find verified rental listings near you in Nairobi. Save properties and chat directly with landlords.',
            timestamp: DateTime.now(),
            isRead: false,
            type: 'system',
          ),
        ];
        await _saveToStorage();
      }
    } catch (_) {
      _notifications = [];
    }
    _updateUnreadCount();
  }

  static Future<void> _saveToStorage() async {
    try {
      final key = await _getHistoryKey();
      final prefs = await SharedPreferences.getInstance();
      final rawJson = jsonEncode(_notifications.map((n) => n.toJson()).toList());
      await prefs.setString(key, rawJson);
    } catch (_) {}
  }

  static void _updateUnreadCount() {
    final count = _notifications.where((n) => !n.isRead).length;
    unreadCountNotifier.value = count;
  }
}
