import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/encryption_service.dart';
import 'package:roost_app/utils/chat_send_error.dart';

void main() {
  const generic = 'Failed to send message. Please check your connection and try again.';

  test('shows the backend reason when the conversation is blocked (403)', () {
    expect(
      chatSendErrorMessage(ApiException("You can't send messages to this person", statusCode: 403)),
      "You can't send messages to this person",
    );
    expect(
      chatSendErrorMessage(ApiException('Unblock this person to message them', statusCode: 403)),
      'Unblock this person to message them',
    );
  });

  test('keeps the secure-messaging messages', () {
    expect(
      chatSendErrorMessage(RecipientKeyUnavailableException()),
      "This user hasn't enabled secure messaging yet.",
    );
    expect(
      chatSendErrorMessage(SecureMessagingSetupException()),
      'Could not set up secure messaging. Please try again.',
    );
  });

  test('uses the generic message for other failures', () {
    expect(chatSendErrorMessage(ApiException('No internet connection')), generic);
    expect(chatSendErrorMessage(ApiException('Request failed', statusCode: 500)), generic);
    expect(chatSendErrorMessage(ApiException('Too many requests.', statusCode: 429)), generic);
    expect(chatSendErrorMessage(StateError('boom')), generic);
  });
}
