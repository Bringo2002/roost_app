import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/utils/chat_notification.dart';

void main() {
  group('ChatNotification.partnerIdFrom', () {
    test('reads the sender id from the payload the backend sends', () {
      // FirebasePushService sends data values as strings.
      expect(
        ChatNotification.partnerIdFrom({'type': 'chat', 'senderId': '42'}),
        42,
      );
    });

    test('accepts a numeric sender id as well as a string', () {
      expect(
        ChatNotification.partnerIdFrom({'type': 'chat', 'senderId': 7}),
        7,
      );
    });

    test('ignores pushes that are not chat messages', () {
      expect(
        ChatNotification.partnerIdFrom({'type': 'listing', 'senderId': '42'}),
        isNull,
      );
      expect(ChatNotification.partnerIdFrom({'senderId': '42'}), isNull);
    });

    test('returns null when there is no payload', () {
      expect(ChatNotification.partnerIdFrom(null), isNull);
      expect(ChatNotification.partnerIdFrom({}), isNull);
    });

    test('returns null when the sender id is missing or unusable', () {
      expect(ChatNotification.partnerIdFrom({'type': 'chat'}), isNull);
      expect(
        ChatNotification.partnerIdFrom({'type': 'chat', 'senderId': 'abc'}),
        isNull,
      );
      expect(
        ChatNotification.partnerIdFrom({'type': 'chat', 'senderId': ''}),
        isNull,
      );
      expect(
        ChatNotification.partnerIdFrom({'type': 'chat', 'senderId': '0'}),
        isNull,
      );
      expect(
        ChatNotification.partnerIdFrom({'type': 'chat', 'senderId': '-3'}),
        isNull,
      );
    });
  });

  group('ChatNotification.isOpenWith', () {
    tearDown(() => ChatNotification.activePartnerId = null);

    test('is false when no conversation is on screen', () {
      expect(ChatNotification.isOpenWith(42), isFalse);
    });

    test('is true only for the partner whose conversation is on screen', () {
      ChatNotification.activePartnerId = 42;

      expect(ChatNotification.isOpenWith(42), isTrue);
      expect(ChatNotification.isOpenWith(43), isFalse);
    });
  });
}
