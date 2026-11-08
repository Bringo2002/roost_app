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
}
