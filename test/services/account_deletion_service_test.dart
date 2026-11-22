import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:roost_app/services/account_deletion_service.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/auth_service.dart';

/// HTTP goes through [ApiService.client] and auth through
/// [AuthService.getTokenOverride]. Both are process-wide statics, so they are
/// reset in tearDown.
void main() {
  setUp(() {
    AuthService.getTokenOverride = () async => 'test-token';
  });

  tearDown(() {
    ApiService.client = http.Client();
    AuthService.getTokenOverride = null;
    AuthService.refreshTokenOverride = null;
  });

  const scheduledBody = '{"status":"scheduled",'
      '"deletionRequestedAt":"2026-11-21T09:00:00",'
      '"deletionScheduledAt":"2026-12-05T09:00:00",'
      '"gracePeriodDays":14}';

  /// Stubs the client with one canned response and returns the list that
  /// records every request it receives.
  List<http.Request> respondWith(int status, String body) {
    final requests = <http.Request>[];
    ApiService.client = MockClient((request) async {
      requests.add(request);
      return http.Response(body, status);
    });
    return requests;
  }

  group('request', () {
    test('posts the confirmed email and password and reads the schedule', () async {
      final requests = respondWith(200, scheduledBody);

      final status = await AccountDeletionService.request(
        email: 'ada@example.com',
        password: 'secret',
      );

      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, endsWith('/api/users/me/delete-account'));
      expect(jsonDecode(requests.single.body), {
        'email': 'ada@example.com',
        'password': 'secret',
      });
      expect(status.isScheduled, isTrue);
      expect(status.gracePeriodDays, 14);
      expect(status.scheduledAt, DateTime.utc(2026, 12, 5, 9));
    });

    test('leaves the password out for an account that has none', () async {
      final requests = respondWith(200, scheduledBody);

      await AccountDeletionService.request(email: 'ada@example.com');

      expect(jsonDecode(requests.single.body), {'email': 'ada@example.com'});
    });

    test('treats an empty password as no password', () async {
      final requests = respondWith(200, scheduledBody);

      await AccountDeletionService.request(email: 'ada@example.com', password: '');

      expect(jsonDecode(requests.single.body), {'email': 'ada@example.com'});
    });

    test('surfaces the backend message when the password is wrong', () async {
      respondWith(400, '{"error":"Password is incorrect"}');

      expect(
        () => AccountDeletionService.request(email: 'ada@example.com', password: 'nope'),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'Password is incorrect')
            .having((e) => e.statusCode, 'statusCode', 400)),
      );
    });

    test('reports a deletion that is already scheduled as a conflict', () async {
      respondWith(409, '{"error":"Account deletion is already scheduled"}');

      expect(
        () => AccountDeletionService.request(email: 'ada@example.com', password: 'secret'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409)),
      );
    });
  });

  group('cancel', () {
    test('posts to the cancel endpoint and reports nothing scheduled', () async {
      final requests =
          respondWith(200, '{"status":"cancelled","gracePeriodDays":14}');

      final status = await AccountDeletionService.cancel();

      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, endsWith('/api/users/me/cancel-deletion'));
      expect(status.status, 'cancelled');
      expect(status.isScheduled, isFalse);
      expect(status.scheduledAt, isNull);
    });
  });

  group('status', () {
    test('reads the current deletion status', () async {
      final requests = respondWith(200, scheduledBody);

      final status = await AccountDeletionService.status();

      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, endsWith('/api/users/me/deletion-status'));
      expect(status.isScheduled, isTrue);
    });

    test('reads "none" when nothing is pending', () async {
      respondWith(200, '{"status":"none","gracePeriodDays":14}');

      final status = await AccountDeletionService.status();

      expect(status.isScheduled, isFalse);
      expect(status.scheduledAt, isNull);
    });
  });
}
