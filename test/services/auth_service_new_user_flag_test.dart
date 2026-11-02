import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/services/auth_service.dart';

void main() {
  group('AuthService.isNewUserFlag', () {
    test('reads the documented isNewUser key', () {
      expect(
        AuthService.isNewUserFlag({'token': 't', 'isNewUser': true}),
        isTrue,
      );
    });

    test('reads newUser, the key the backend serializes today', () {
      expect(
        AuthService.isNewUserFlag({'token': 't', 'newUser': true}),
        isTrue,
      );
    });

    test('is false when the flag is false under either key', () {
      expect(AuthService.isNewUserFlag({'isNewUser': false}), isFalse);
      expect(AuthService.isNewUserFlag({'newUser': false}), isFalse);
    });

    test('is false when the flag is missing', () {
      expect(AuthService.isNewUserFlag({'token': 't'}), isFalse);
    });

    test('is false for a non-boolean value', () {
      expect(AuthService.isNewUserFlag({'newUser': 'true'}), isFalse);
      expect(AuthService.isNewUserFlag({'isNewUser': 1}), isFalse);
    });

    test('is false when the response is not a JSON object', () {
      expect(AuthService.isNewUserFlag(null), isFalse);
      expect(AuthService.isNewUserFlag('oops'), isFalse);
      expect(AuthService.isNewUserFlag(<dynamic>[]), isFalse);
    });
  });
}
