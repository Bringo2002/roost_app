import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/encryption_service.dart';

/// The message to show when sending a chat message fails.
///
/// A 403 means one of the two people has blocked the other; the backend's
/// reason ("Unblock this person to message them" or "You can't send messages
/// to this person") is already worded for the sender, so it is shown as-is.
/// The secure-messaging errors carry their own safe text. Everything else is
/// treated as a connection problem.
String chatSendErrorMessage(Object error) {
  if (error is RecipientKeyUnavailableException || error is SecureMessagingSetupException) {
    return error.toString();
  }
  if (error is ApiException && error.statusCode == 403) {
    return error.message;
  }
  return 'Failed to send message. Please check your connection and try again.';
}
