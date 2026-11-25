import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:roost_app/pages/profile/blocked_users_page.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/auth_service.dart';

/// HTTP is stubbed through [ApiService.client] and the token through
/// [AuthService.getTokenOverride], the same seams the other page tests use.
/// Both are process-wide statics, so they are reset in tearDown.
void main() {
  const twoBlocked = '[{"id":7,"name":"Ada","avatarUrl":null,"blockedAt":"2026-11-20T10:00:00"},'
      '{"id":8,"name":"Grace","avatarUrl":null,"blockedAt":"2026-11-19T08:30:00"}]';

  setUp(() {
    AuthService.getTokenOverride = () async => 'test-token';
  });

  tearDown(() {
    ApiService.client = http.Client();
    AuthService.getTokenOverride = null;
    AuthService.refreshTokenOverride = null;
  });

  /// Stubs the client with [handler] and returns the list of requests seen.
  List<http.Request> stub(http.Response Function(http.Request request) handler) {
    final requests = <http.Request>[];
    ApiService.client = MockClient((request) async {
      requests.add(request);
      return handler(request);
    });
    return requests;
  }

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: BlockedUsersPage()));
    await tester.pumpAndSettle();
  }

  testWidgets('lists the people you blocked', (tester) async {
    final requests = stub((_) => http.Response(twoBlocked, 200));

    await pumpPage(tester);

    expect(requests.single.method, 'GET');
    expect(requests.single.url.path, endsWith('/api/users/me/blocked'));
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Grace'), findsOneWidget);
    expect(find.byKey(const Key('unblock-7')), findsOneWidget);
    expect(find.byKey(const Key('unblock-8')), findsOneWidget);
  });

  testWidgets('says so when nobody is blocked', (tester) async {
    stub((_) => http.Response('[]', 200));

    await pumpPage(tester);

    expect(find.text("You haven't blocked anyone."), findsOneWidget);
  });

  testWidgets('shows the failure and loads again on retry', (tester) async {
    var calls = 0;
    stub((_) {
      calls++;
      return calls == 1
          ? http.Response('{"error":"Server exploded"}', 500)
          : http.Response(twoBlocked, 200);
    });

    await pumpPage(tester);

    expect(find.text('Server exploded'), findsOneWidget);
    expect(find.text('Ada'), findsNothing);

    await tester.tap(find.byKey(const Key('blocked-retry-button')));
    await tester.pumpAndSettle();

    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Server exploded'), findsNothing);
  });

  testWidgets('unblocking removes that person and confirms', (tester) async {
    final requests = stub((request) => request.method == 'DELETE'
        ? http.Response('{"blocked":false}', 200)
        : http.Response(twoBlocked, 200));

    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('unblock-7')));
    await tester.pumpAndSettle();

    final delete = requests.firstWhere((r) => r.method == 'DELETE');
    expect(delete.url.path, endsWith('/api/users/7/block'));
    expect(find.text('Ada'), findsNothing);
    expect(find.text('Grace'), findsOneWidget);
    expect(find.text('Ada unblocked'), findsOneWidget);
  });

  testWidgets('a failed unblock keeps the person and shows why', (tester) async {
    stub((request) => request.method == 'DELETE'
        ? http.Response('{"error":"User not found"}', 404)
        : http.Response(twoBlocked, 200));

    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('unblock-7')));
    await tester.pumpAndSettle();

    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('User not found'), findsOneWidget);
  });
}
