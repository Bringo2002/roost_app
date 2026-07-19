import 'package:roost_app/models/user.dart';

/// Summary of a conversation for the active-chats list. Contains the
/// partner, the last message (as ciphertext — the client decrypts it
/// locally), and the unread count.
class ConversationSummary {
  final User partner;

  /// Encrypted ciphertext of the last message. Null if no messages yet.
  final String? lastMessageContent;

  /// Nonce for [lastMessageContent]. Null for legacy plaintext or if
  /// no messages.
  final String? lastMessageNonce;

  final DateTime? lastMessageTimestamp;

  /// ID of the sender of the last message. Needed to know whether to
  /// show "You: ..." or just the message preview.
  final int? lastMessageSenderId;

  final int unreadCount;

  /// Encrypted metadata JSON for the last message's attachment.
  final String? lastMessageAttachmentMeta;
  final String? lastMessageAttachmentMetaNonce;
  final bool hasAttachment;

  /// Decrypted preview text — populated client-side after decryption.
  String? decryptedPreview;

  ConversationSummary({
    required this.partner,
    this.lastMessageContent,
    this.lastMessageNonce,
    this.lastMessageTimestamp,
    this.lastMessageSenderId,
    this.unreadCount = 0,
    this.lastMessageAttachmentMeta,
    this.lastMessageAttachmentMetaNonce,
    this.hasAttachment = false,
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    return ConversationSummary(
      partner: User.fromJson(json['partner']),
      lastMessageContent: json['lastMessageContent'],
      lastMessageNonce: json['lastMessageNonce'],
      lastMessageTimestamp: json['lastMessageTimestamp'] != null
          ? DateTime.parse(json['lastMessageTimestamp'])
          : null,
      lastMessageSenderId: (json['lastMessageSenderId'] as num?)?.toInt(),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      lastMessageAttachmentMeta: json['lastMessageAttachmentMeta'],
      lastMessageAttachmentMetaNonce: json['lastMessageAttachmentMetaNonce'],
      hasAttachment: json['hasAttachment'] == true,
    );
  }
}
