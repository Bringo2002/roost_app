import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/models/user.dart';

void main() {
  group('User Model Tests', () {
    test('User.fromJson parses avatarUrl when present', () {
      final json = {
        'id': 42,
        'name': 'Jane Doe',
        'email': 'jane@example.com',
        'role': 'TENANT',
        'phone': '+254700000000',
        'avatarUrl': 'https://res.cloudinary.com/roost/image/upload/v12345/avatar.jpg',
      };

      final user = User.fromJson(json);

      expect(user.id, equals(42));
      expect(user.name, equals('Jane Doe'));
      expect(user.email, equals('jane@example.com'));
      expect(user.role, equals('TENANT'));
      expect(user.phone, equals('+254700000000'));
      expect(user.avatarUrl, equals('https://res.cloudinary.com/roost/image/upload/v12345/avatar.jpg'));
    });

    test('User.fromJson falls back to profilePicUrl if avatarUrl is missing', () {
      final json = {
        'id': 10,
        'name': 'John Landlord',
        'email': 'john@example.com',
        'role': 'LANDLORD',
        'profilePicUrl': 'https://example.com/pics/john.png',
      };

      final user = User.fromJson(json);

      expect(user.avatarUrl, equals('https://example.com/pics/john.png'));
    });

    test('User.fromJson handles null avatarUrl gracefully', () {
      final json = {
        'id': 1,
        'name': 'No Avatar User',
        'email': 'noavatar@example.com',
        'role': 'TENANT',
      };

      final user = User.fromJson(json);

      expect(user.avatarUrl, isNull);
    });
  });
}
