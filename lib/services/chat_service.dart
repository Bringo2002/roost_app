import 'api_service.dart';
import '../models/user.dart';
import '../models/message.dart';

class ChatService {
  static Future<List<User>> getActiveChats() async {
    final response = await ApiService.get('/api/chat/active');
    if (response is List) {
      return response.map((json) => User.fromJson(json)).toList();
    }
    return [];
  }

  static Future<List<Message>> getChatHistory(int userId) async {
    final response = await ApiService.get('/api/chat/history/$userId');
    if (response is List) {
      return response.map((json) => Message.fromJson(json)).toList();
    }
    return [];
  }

  static Future<Message?> sendMessage(int recipientId, String content) async {
    final response = await ApiService.post('/api/chat', {
      'recipientId': recipientId,
      'content': content,
    });
    if (response != null) {
      return Message.fromJson(response);
    }
    return null;
  }

  static Future<void> markAsRead(int userId) async {
    try {
      await ApiService.post('/api/chat/mark-read/$userId', {});
    } catch (_) {}
  }
}
