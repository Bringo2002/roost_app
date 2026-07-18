import 'package:roost_app/models/user.dart';

class Message {
  final int id;
  final User sender;
  final User recipient;

  /// Holds ciphertext as received from the wire until [ChatService]
  /// decrypts it in place; from then on holds plaintext. Deliberately
  /// mutable so the network layer can decrypt without re-parsing.
  String content;

  /// Base64-encoded nonce used to encrypt [content]. Null for legacy
  /// plaintext messages sent before end-to-end encryption shipped.
  final String? nonce;

  final DateTime timestamp;

  Message({
    required this.id,
    required this.sender,
    required this.recipient,
    required this.content,
    this.nonce,
    required this.timestamp,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: (json['id'] as num?)?.toInt() ?? 0,
      sender: json['sender'] != null ? User.fromJson(json['sender']) : User(id: 0, name: 'Unknown', email: '', role: ''),
      recipient: json['recipient'] != null ? User.fromJson(json['recipient']) : User(id: 0, name: 'Unknown', email: '', role: ''),
      content: json['content'] ?? '',
      nonce: json['nonce'],
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
    );
  }
}
