import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:roost_app/services/auth_service.dart';

http.Response _json(int status, Map<String, dynamic> body) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  String? savedToken;

  setUp(() {
    savedToken = null;
    AuthService.saveTokenOverride = (token) async => savedToken = token;
  });

  tearDown(() {
    AuthService.saveTokenOverride = null;
  });

  group('AuthService.signup', () {
    test('flags the result as a new user so routing starts onboarding',
        () async {
      final result = await http.runWithClient(
        () => AuthService.signup('Ada', 'ada@example.com', 'secret123'),
        () => MockClient((_) async => _json(200, {'token': 'jwt-123'})),
      );

      expect(result.success, isTrue);
      expect(result.isNewUser, isTrue);
      expect(savedToken, 'jwt-123');
    });

    test('a rejected signup is neither a success nor a new user', () async {
      final result = await http.runWithClient(
        () => AuthService.signup('Ada', 'ada@example.com', 'secret123'),
        () => MockClient(
          (_) async => _json(409, {'error': 'Email already registered'}),
        ),
      );

      expect(result.success, isFalse);
      expect(result.isNewUser, isFalse);
      expect(result.error, 'Email already registered');
      expect(savedToken, isNull);
    });
  });

  group('AuthService.login', () {
    test('never flags an existing account as a new user', () async {
      final result = await http.runWithClient(
        () => AuthService.login('ada@example.com', 'secret123'),
        () => MockClient((_) async => _json(200, {'token': 'jwt-456'})),
      );

      expect(result.success, isTrue);
      expect(result.isNewUser, isFalse);
      expect(savedToken, 'jwt-456');
    });
  });
}
