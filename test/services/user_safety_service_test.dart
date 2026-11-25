import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:roost_app/models/report_reason.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/auth_service.dart';
import 'package:roost_app/services/user_safety_service.dart';

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

  group('block', () {
    test('posts to the block endpoint for that user', () async {
      final requests = respondWith(200, '{"blocked":true}');

      await UserSafetyService.block(5);

      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, endsWith('/api/users/5/block'));
    });

    test('surfaces the backend message when blocking yourself is refused', () async {
      respondWith(400, '{"error":"You can\'t block yourself"}');

      expect(
        () => UserSafetyService.block(1),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', "You can't block yourself")
            .having((e) => e.statusCode, 'statusCode', 400)),
      );
    });
  });

  group('unblock', () {
    test('sends a DELETE to the block endpoint for that user', () async {
      final requests = respondWith(200, '{"blocked":false}');

      await UserSafetyService.unblock(5);

      expect(requests.single.method, 'DELETE');
      expect(requests.single.url.path, endsWith('/api/users/5/block'));
    });

    test('reports a failure instead of swallowing it', () async {
      respondWith(404, '{"error":"User not found"}');

      expect(
        () => UserSafetyService.unblock(99),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404)),
      );
    });
  });

  group('blockedUsers', () {
    test('reads the list from the backend', () async {
      final requests = respondWith(
        200,
        '[{"id":7,"name":"Ada","avatarUrl":null,"blockedAt":"2026-11-20T10:00:00"},'
        '{"id":8,"name":"Grace","avatarUrl":"https://cdn.example/g.jpg","blockedAt":"2026-11-19T08:30:00"}]',
      );

      final users = await UserSafetyService.blockedUsers();

      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, endsWith('/api/users/me/blocked'));
      expect(users.map((u) => u.id), [7, 8]);
      expect(users.first.name, 'Ada');
      expect(users.last.avatarUrl, 'https://cdn.example/g.jpg');
    });

    test('is empty when nobody is blocked', () async {
      respondWith(200, '[]');

      expect(await UserSafetyService.blockedUsers(), isEmpty);
    });
  });

  group('report', () {
    test('posts the reason and the trimmed note', () async {
      final requests = respondWith(200, '{"reported":true}');

      await UserSafetyService.report(5, ReportReason.harassment, note: '  keeps insulting me  ');

      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, endsWith('/api/users/5/report'));
      expect(jsonDecode(requests.single.body), {
        'reason': 'HARASSMENT',
        'note': 'keeps insulting me',
      });
    });

    test('leaves the note out when there is none', () async {
      final requests = respondWith(200, '{"reported":true}');

      await UserSafetyService.report(5, ReportReason.spam);

      expect(jsonDecode(requests.single.body), {'reason': 'SPAM'});
    });

    test('treats a blank note as no note', () async {
      final requests = respondWith(200, '{"reported":true}');

      await UserSafetyService.report(5, ReportReason.scamOrFraud, note: '   ');

      expect(jsonDecode(requests.single.body), {'reason': 'SCAM_OR_FRAUD'});
    });

    test('reports a duplicate report as a conflict with the backend message', () async {
      respondWith(409, '{"error":"You\'ve already reported this user. Our team will review it."}');

      expect(
        () => UserSafetyService.report(5, ReportReason.other),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.message, 'message', contains('already reported'))),
      );
    });
  });
}
