/// Helpers for chat push notifications.
class ChatNotification {
  ChatNotification._();

  /// The id of the user who sent the message behind a chat push, or null
  /// when [payload] is not a usable chat push.
  ///
  /// The backend (`FirebasePushService`) sends `type: chat` plus the
  /// sender's user id as `senderId`. FCM data values are always strings,
  /// so the id is parsed rather than cast.
  static int? partnerIdFrom(Map<String, dynamic>? payload) {
    if (payload == null || payload['type'] != 'chat') return null;
    final id = int.tryParse('${payload['senderId']}');
    if (id == null || id <= 0) return null;
    return id;
  }

  /// The partner whose `ChatRoomPage` is currently on screen, or null.
  /// Set by the page itself so a push about a conversation the user is
  /// already looking at neither pops a banner nor opens a second copy.
  static int? activePartnerId;

  /// Whether the conversation with [partnerId] is on screen right now.
  static bool isOpenWith(int partnerId) => activePartnerId == partnerId;
}
