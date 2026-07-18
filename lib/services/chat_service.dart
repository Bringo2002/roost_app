import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/encryption_service.dart';
import 'package:roost_app/models/user.dart';
import 'package:roost_app/models/message.dart';

class ChatService {
  static Future<List<User>> getActiveChats() async {
    final response = await ApiService.get('/api/chat/active');
    if (response is List) {
      return response.map((json) => User.fromJson(json)).toList();
    }
    return [];
  }

  /// Fetches the encrypted history with [userId] and decrypts every
  /// message in place before returning -- callers always receive
  /// plaintext, never ciphertext.
  static Future<List<Message>> getChatHistory(int userId) async {
    final response = await ApiService.get('/api/chat/history/$userId');
    if (response is! List) return [];

    final messages = response.map((json) => Message.fromJson(json)).toList();
    for (final message in messages) {
      message.content = await EncryptionService.decryptFrom(
        userId,
        message.content,
        message.nonce,
      );
    }
    return messages;
  }

  /// Encrypts [content] for [recipientId] end-to-end, sends it, and
  /// returns a [Message] with the original plaintext already attached
  /// (no need to round-trip a decrypt for a message we just wrote).
  ///
  /// Throws [RecipientKeyUnavailableException] if the recipient hasn't
  /// enabled secure messaging yet.
  static Future<Message?> sendMessage(int recipientId, String content) async {
    final encrypted = await EncryptionService.encryptFor(recipientId, content);
    final response = await ApiService.post('/api/chat', {
      'recipientId': recipientId,
      'content': encrypted.content,
      'nonce': encrypted.nonce,
    });
    if (response == null) return null;

    final message = Message.fromJson(response);
    message.content = content;
    return message;
  }

  static Future<void> markAsRead(int userId) async {
    try {
      await ApiService.post('/api/chat/mark-read/$userId', {});
    } catch (_) {}
  }
}
