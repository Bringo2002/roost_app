import 'package:roost_app/models/blocked_user.dart';
import 'package:roost_app/models/report_reason.dart';
import 'package:roost_app/services/api_service.dart';

/// Blocking and reporting other users.
///
/// Failures throw [ApiException] carrying the backend's message and status,
/// for example a 409 when the same user was already reported today.
class UserSafetyService {
  UserSafetyService._();

  /// Blocks [userId]. Blocking someone already blocked succeeds.
  ///
  /// Their messages, conversation and unread count are hidden from you, and
  /// neither of you can message the other until you unblock them.
  static Future<void> block(int userId) async {
    await ApiService.post('/api/users/$userId/block');
  }

  /// Unblocks [userId]. Unblocking someone who is not blocked succeeds.
  static Future<void> unblock(int userId) async {
    await ApiService.delete('/api/users/$userId/block');
  }

  /// The people you have blocked, newest block first.
  static Future<List<BlockedUser>> blockedUsers() async {
    final data = await ApiService.get('/api/users/me/blocked');
    return (data as List)
        .map((entry) => BlockedUser.fromJson(Map<String, dynamic>.from(entry as Map)))
        .toList(growable: false);
  }

  /// Reports [userId] for review.
  ///
  /// [note] is optional extra detail, at most [kMaxReportNoteLength]
  /// characters; a blank note is left out. The backend answers 409 when you
  /// have already reported this user in the last 24 hours.
  static Future<void> report(int userId, ReportReason reason, {String? note}) async {
    final body = <String, dynamic>{'reason': reason.apiValue};
    final trimmed = note?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      body['note'] = trimmed;
    }
    await ApiService.post('/api/users/$userId/report', body);
  }
}
