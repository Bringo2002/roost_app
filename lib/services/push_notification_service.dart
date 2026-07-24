import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:roost_app/services/api_service.dart';

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

/// Manages push notifications, local history, and device token registration for Roost.
class PushNotificationService {
  PushNotificationService._();

  static bool _initialized = false;
  static String? _fcmToken;
  static const String _prefEnabledKey = 'push_notifications_enabled';
  static const String _prefHistoryKey = 'notification_history_v1';

  /// ValueNotifier exposing unread notification count across the app
  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  /// In-memory notification list
  static List<NotificationItem> _notifications = [];

  /// Initializes notification channels, loads settings, and registers device token.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _loadFromStorage();

    try {
      if (await isEnabled()) {
        _fcmToken = 'roost_device_token_${DateTime.now().millisecondsSinceEpoch}';
        await registerTokenWithBackend(_fcmToken!);
      }
    } catch (_) {}
  }

  /// Checks if push notifications are enabled (defaults to true)
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefEnabledKey) ?? true;
  }

  /// Enables or disables push notifications
  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabledKey, enabled);
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

  /// Returns all stored notifications
  static List<NotificationItem> getNotifications() {
    return List.unmodifiable(_notifications);
  }

  /// Adds a new incoming notification, saves to storage, and notifies listeners
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

  /// Marks all notifications as read
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

  /// Clears all notification history
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
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_prefHistoryKey);
      if (rawJson != null && rawJson.isNotEmpty) {
        final List decoded = jsonDecode(rawJson);
        _notifications = decoded.map((j) => NotificationItem.fromJson(j)).toList();
      } else {
        // Initial sample welcome notification for production polish
        _notifications = [
          NotificationItem(
            id: 'welcome_1',
            title: 'Welcome to Roost!',
            body: 'Find verified rental listings near you in Nairobi. Save properties and chat directly with landlords.',
            timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
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
      final prefs = await SharedPreferences.getInstance();
      final rawJson = jsonEncode(_notifications.map((n) => n.toJson()).toList());
      await prefs.setString(_prefHistoryKey, rawJson);
    } catch (_) {}
  }

  static void _updateUnreadCount() {
    final count = _notifications.where((n) => !n.isRead).length;
    unreadCountNotifier.value = count;
  }
}
