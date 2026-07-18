import 'dart:typed_data';
import 'package:roost_app/models/user.dart';

class Message {
  final int id;
  final User sender;
  final User recipient;

  /// Holds ciphertext as received from the wire until [ChatService]
  /// decrypts it in place; from then on holds plaintext. Deliberately
  /// mutable so the network layer can decrypt without re-parsing. Empty
  /// for attachment-only messages with no caption.
  String content;

  /// Base64-encoded nonce used to encrypt [content]. Null for legacy
  /// plaintext messages sent before end-to-end encryption shipped, or for
  /// attachment-only messages.
  final String? nonce;

  final DateTime timestamp;

  /// True once the recipient has opened this conversation and it's been
  /// marked read server-side. Drives the sent/read receipt ticks.
  final bool read;

  // --- Encrypted attachment, as received from the wire ---
  final String? attachmentData;
  final String? attachmentNonce;
  final String? attachmentMeta;
  final String? attachmentMetaNonce;

  // --- Populated by ChatService after decryption ---
  Uint8List? attachmentBytes;
  String? attachmentFileName;
  String? attachmentMimeType;
  int? attachmentSizeBytes;

  bool get hasAttachment => attachmentData != null && attachmentData!.isNotEmpty;

  Message({
    required this.id,
    required this.sender,
    required this.recipient,
    required this.content,
    this.nonce,
    required this.timestamp,
    this.read = false,
    this.attachmentData,
    this.attachmentNonce,
    this.attachmentMeta,
    this.attachmentMetaNonce,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: (json['id'] as num?)?.toInt() ?? 0,
      sender: json['sender'] != null ? User.fromJson(json['sender']) : User(id: 0, name: 'Unknown', email: '', role: ''),
      recipient: json['recipient'] != null ? User.fromJson(json['recipient']) : User(id: 0, name: 'Unknown', email: '', role: ''),
      content: json['content'] ?? '',
      nonce: json['nonce'],
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
      read: json['read'] == true,
      attachmentData: json['attachmentData'],
      attachmentNonce: json['attachmentNonce'],
      attachmentMeta: json['attachmentMeta'],
      attachmentMetaNonce: json['attachmentMetaNonce'],
    );
  }
}
