import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/models/blocked_user.dart';

void main() {
  group('BlockedUser.fromJson', () {
    test('reads every field of the backend BlockedUserDto', () {
      final user = BlockedUser.fromJson({
        'id': 7,
        'name': 'Ada Lovelace',
        'avatarUrl': 'https://cdn.example/a.jpg',
        'blockedAt': '2026-11-20T10:00:00',
      });

      expect(user.id, 7);
      expect(user.name, 'Ada Lovelace');
      expect(user.avatarUrl, 'https://cdn.example/a.jpg');
      // The server sends UTC wall-clock time with no zone designator.
      expect(user.blockedAt, DateTime.utc(2026, 11, 20, 10));
    });

    test('accepts a missing photo', () {
      final user = BlockedUser.fromJson({
        'id': 7,
        'name': 'Ada',
        'avatarUrl': null,
        'blockedAt': '2026-11-20T10:00:00.123456',
      });

      expect(user.avatarUrl, isNull);
    });

    test('accepts a numeric id sent as a double', () {
      final user = BlockedUser.fromJson({
        'id': 7.0,
        'name': 'Ada',
        'blockedAt': '2026-11-20T10:00:00',
      });

      expect(user.id, 7);
    });

    test('a response without an id is a contract break, not a default', () {
      expect(
        () => BlockedUser.fromJson({'name': 'Ada', 'blockedAt': '2026-11-20T10:00:00'}),
        throwsA(isA<TypeError>()),
      );
    });

    test('a response without blockedAt is a contract break, not a default', () {
      expect(
        () => BlockedUser.fromJson({'id': 7, 'name': 'Ada'}),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('BlockedUser.displayName', () {
    test('is the name when there is one', () {
      final user = BlockedUser(id: 1, name: 'Ada', blockedAt: DateTime.utc(2026));
      expect(user.displayName, 'Ada');
    });

    test('falls back when the name is missing or blank', () {
      expect(BlockedUser(id: 1, blockedAt: DateTime.utc(2026)).displayName, 'Roost user');
      expect(BlockedUser(id: 1, name: '  ', blockedAt: DateTime.utc(2026)).displayName, 'Roost user');
    });
  });

  group('BlockedUser.initial', () {
    test('is the first letter of the name, upper-cased', () {
      expect(BlockedUser(id: 1, name: 'ada', blockedAt: DateTime.utc(2026)).initial, 'A');
    });

    test('is a question mark with no usable name', () {
      expect(BlockedUser(id: 1, blockedAt: DateTime.utc(2026)).initial, '?');
    });
  });
}
