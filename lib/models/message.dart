import 'user.dart';

class Message {
  final int id;
  final User sender;
  final User recipient;
  final String content;
  final DateTime timestamp;

  Message({
    required this.id,
    required this.sender,
    required this.recipient,
    required this.content,
    required this.timestamp,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: (json['id'] as num?)?.toInt() ?? 0,
      sender: json['sender'] != null ? User.fromJson(json['sender']) : User(id: 0, name: 'Unknown', email: '', role: ''),
      recipient: json['recipient'] != null ? User.fromJson(json['recipient']) : User(id: 0, name: 'Unknown', email: '', role: ''),
      content: json['content'] ?? '',
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
    );
  }
}
