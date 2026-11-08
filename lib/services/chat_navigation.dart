import 'package:flutter/material.dart';
import 'package:roost_app/pages/chat/chat_room_page.dart';
import 'package:roost_app/services/chat_service.dart';
import 'package:roost_app/services/navigator_key.dart';
import 'package:roost_app/utils/chat_notification.dart';

/// Opens a conversation from outside the widget tree, e.g. when the user
/// taps a chat push notification.
class ChatNavigation {
  ChatNavigation._();

  /// Partner whose conversation is being fetched for opening right now.
  /// Stops a second call for the same partner (a double tap, or a push
  /// delivered to two listeners) from stacking two chat pages.
  static int? _openingPartnerId;

  /// Opens the conversation with [partnerId] on the root navigator.
  ///
  /// Does nothing if that conversation is already on screen or is already
  /// being opened. Shows a SnackBar if the partner's profile can't be
  /// loaded, so a tap is never silently ignored.
  static Future<void> openChatWith(int partnerId) async {
    if (ChatNotification.isOpenWith(partnerId) ||
        _openingPartnerId == partnerId) {
      return;
    }
    _openingPartnerId = partnerId;
    try {
      final partner = await ChatService.getUserProfile(partnerId);
      final navigator = navigatorKey.currentState;
      if (navigator == null) return;
      if (partner == null) {
        _showOpenFailed();
        return;
      }
      if (ChatNotification.isOpenWith(partnerId)) return;
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => ChatRoomPage(partner: partner),
        ),
      );
    } finally {
      _openingPartnerId = null;
    }
  }

  static void _showOpenFailed() {
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text(
          "Couldn't open that conversation. Check your connection and try again.",
        ),
      ),
    );
  }
}
