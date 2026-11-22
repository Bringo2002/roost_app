import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:roost_app/pages/profile/delete_account_page.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/auth_service.dart';

/// HTTP is stubbed through [ApiService.client] and the token through
/// [AuthService.getTokenOverride], the same seams the other page tests use.
/// Both are process-wide statics, so they are reset in tearDown.
void main() {
  const accountEmail = 'ada@example.com';
  const scheduledBody = '{"status":"scheduled",'
      '"deletionRequestedAt":"2026-11-21T09:00:00",'
      '"deletionScheduledAt":"2026-12-05T12:00:00",'
      '"gracePeriodDays":14}';

  setUp(() {
    AuthService.getTokenOverride = () async => 'test-token';
  });

  tearDown(() {
    ApiService.client = http.Client();
    AuthService.getTokenOverride = null;
    AuthService.refreshTokenOverride = null;
  });

  List<http.Request> stub(int status, String body) {
    final requests = <http.Request>[];
    ApiService.client = MockClient((request) async {
      requests.add(request);
      return http.Response(body, status);
    });
    return requests;
  }

  /// A tall surface so the whole form is on screen without scrolling.
  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpPage(WidgetTester tester, {required bool requiresPassword}) async {
    useTallScreen(tester);
    await tester.pumpWidget(MaterialApp(
      home: DeleteAccountPage(email: accountEmail, requiresPassword: requiresPassword),
    ));
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('delete-submit-button')));
    await tester.pumpAndSettle();
  }

  testWidgets('asks for a password only when the account has one', (tester) async {
    await pumpPage(tester, requiresPassword: true);
    expect(find.byKey(const Key('delete-password-field')), findsOneWidget);

    await pumpPage(tester, requiresPassword: false);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('delete-password-field')), findsNothing);
  });

  testWidgets('refuses an email that does not match, without calling the server', (tester) async {
    final requests = stub(200, scheduledBody);
    await pumpPage(tester, requiresPassword: false);

    await tester.enterText(find.byKey(const Key('delete-email-field')), 'someone@else.com');
    await submit(tester);

    expect(find.text('This does not match your account email'), findsOneWidget);
    expect(requests, isEmpty);
  });

  testWidgets('requires the email to be typed', (tester) async {
    final requests = stub(200, scheduledBody);
    await pumpPage(tester, requiresPassword: false);

    await submit(tester);

    expect(find.text('Type your email to confirm'), findsWidgets);
    expect(requests, isEmpty);
  });

  testWidgets('requires the password for an account that has one', (tester) async {
    final requests = stub(200, scheduledBody);
    await pumpPage(tester, requiresPassword: true);

    await tester.enterText(find.byKey(const Key('delete-email-field')), accountEmail);
    await submit(tester);

    expect(find.text('Enter your password'), findsOneWidget);
    expect(requests, isEmpty);
  });

  testWidgets('sends the email and password, then shows the scheduled date', (tester) async {
    final requests = stub(200, scheduledBody);
    await pumpPage(tester, requiresPassword: true);

    await tester.enterText(find.byKey(const Key('delete-email-field')), accountEmail);
    await tester.enterText(find.byKey(const Key('delete-password-field')), 'secret');
    await submit(tester);

    expect(requests.single.url.path, endsWith('/api/users/me/delete-account'));
    expect(jsonDecode(requests.single.body), {'email': accountEmail, 'password': 'secret'});
    expect(find.text('Deletion scheduled'), findsOneWidget);
    expect(find.textContaining('December 2026'), findsOneWidget);
    expect(find.byKey(const Key('delete-done-button')), findsOneWidget);
  });

  testWidgets('accepts the email in any case and sends no password when there is none', (tester) async {
    final requests = stub(200, scheduledBody);
    await pumpPage(tester, requiresPassword: false);

    await tester.enterText(find.byKey(const Key('delete-email-field')), '  Ada@Example.com ');
    await submit(tester);

    expect(jsonDecode(requests.single.body), {'email': 'Ada@Example.com'});
    expect(find.text('Deletion scheduled'), findsOneWidget);
  });

  testWidgets('shows the backend message when the request is refused', (tester) async {
    stub(400, '{"error":"Password is incorrect"}');
    await pumpPage(tester, requiresPassword: true);

    await tester.enterText(find.byKey(const Key('delete-email-field')), accountEmail);
    await tester.enterText(find.byKey(const Key('delete-password-field')), 'wrong');
    await submit(tester);

    expect(find.text('Password is incorrect'), findsOneWidget);
    expect(find.text('Deletion scheduled'), findsNothing);
    expect(find.byKey(const Key('delete-submit-button')), findsOneWidget);
  });

  testWidgets('Done hands back true so the caller can sign the user out', (tester) async {
    stub(200, scheduledBody);
    useTallScreen(tester);
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DeleteAccountPage(
                      email: accountEmail,
                      requiresPassword: false,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('delete-email-field')), accountEmail);
    await submit(tester);
    await tester.tap(find.byKey(const Key('delete-done-button')));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });
}
