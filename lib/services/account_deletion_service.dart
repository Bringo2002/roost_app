import 'package:roost_app/models/account_deletion_status.dart';
import 'package:roost_app/services/api_service.dart';

/// Self-service account deletion. The backend schedules the deletion after a
/// grace period, during which the account keeps working and the request can
/// be cancelled.
///
/// Failures throw [ApiException], carrying the backend's message (for
/// example a wrong password, or a deletion that is already scheduled).
class AccountDeletionService {
  AccountDeletionService._();

  /// Asks for the account to be deleted after the grace period.
  ///
  /// [email] is the address the user typed to confirm. [password] is sent
  /// only when given: accounts created through Google or Apple sign-in have
  /// no password, and the backend does not ask them for one.
  static Future<AccountDeletionStatus> request({
    required String email,
    String? password,
  }) async {
    final body = <String, dynamic>{'email': email};
    if (password != null && password.isNotEmpty) {
      body['password'] = password;
    }
    final data = await ApiService.post('/api/users/me/delete-account', body);
    return _parse(data);
  }

  /// Cancels a scheduled deletion.
  static Future<AccountDeletionStatus> cancel() async {
    final data = await ApiService.post('/api/users/me/cancel-deletion');
    return _parse(data);
  }

  /// Reads whether a deletion is currently scheduled.
  static Future<AccountDeletionStatus> status() async {
    final data = await ApiService.get('/api/users/me/deletion-status');
    return _parse(data);
  }

  static AccountDeletionStatus _parse(dynamic data) {
    return AccountDeletionStatus.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
