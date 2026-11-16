import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:roost_app/models/identity_review.dart';
import 'package:roost_app/pages/admin/admin_identity_review_page.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/auth_service.dart';

/// The admin identity review screens. HTTP is stubbed through
/// [ApiService.client] and the token through [AuthService.getTokenOverride],
/// the same seams the other page tests use. Both are process-wide statics,
/// so they are reset in tearDown.
void main() {
  setUp(() {
    AuthService.getTokenOverride = () async => 'test-token';
  });

  tearDown(() {
    ApiService.client = http.Client();
    AuthService.getTokenOverride = null;
  });

  // A tiny picture; the tests only need bytes that arrive, not that decode.
  final fileBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  );

  IdentityReview review({List<IdentityDocument>? documents}) => IdentityReview(
        userId: 7,
        name: 'Mama Wanjiku',
        documents: documents ??
            const [
              IdentityDocument(
                id: 11,
                docType: 'NATIONAL_ID_FRONT',
                status: 'SUBMITTED',
                contentType: 'image/png',
                sizeBytes: 100,
              ),
              IdentityDocument(
                id: 12,
                docType: 'NATIONAL_ID_BACK',
                status: 'SUBMITTED',
                contentType: 'image/png',
                sizeBytes: 100,
              ),
            ],
      );

  // ── queue ──────────────────────────────────────────────────────────────

  group('queue', () {
    void stubPending(String body, [int status = 200]) {
      ApiService.client = MockClient((request) async {
        if (request.method == 'GET' && request.url.path.endsWith('/identity/pending')) {
          return http.Response(body, status);
        }
        return http.Response('', 404);
      });
    }

    testWidgets('lists each lister who is waiting, with their document count', (tester) async {
      stubPending(jsonEncode([
        {
          'userId': 7,
          'name': 'Mama Wanjiku',
          'documents': [
            {'id': 11, 'docType': 'NATIONAL_ID_FRONT', 'contentType': 'image/jpeg'},
            {'id': 12, 'docType': 'NATIONAL_ID_BACK', 'contentType': 'image/jpeg'},
          ],
        },
      ]));

      await tester.pumpWidget(const MaterialApp(home: AdminIdentityReviewPage()));
      await tester.pumpAndSettle();

      expect(find.text('Mama Wanjiku'), findsOneWidget);
      expect(find.text('2 documents'), findsOneWidget);
    });

    testWidgets('says so when nobody is waiting', (tester) async {
      stubPending('[]');

      await tester.pumpWidget(const MaterialApp(home: AdminIdentityReviewPage()));
      await tester.pumpAndSettle();

      expect(find.text('No identity documents waiting for review.'), findsOneWidget);
    });

    testWidgets('shows the server message and a retry when loading fails', (tester) async {
      stubPending('{"error":"Admin access required"}', 403);

      await tester.pumpWidget(const MaterialApp(home: AdminIdentityReviewPage()));
      await tester.pumpAndSettle();

      expect(find.text('Admin access required'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  // ── detail ─────────────────────────────────────────────────────────────

  group('detail', () {
    /// Stubs the file downloads and the decision, recording every request.
    List<http.Request> stubServer({int decisionStatus = 204, String decisionBody = ''}) {
      final requests = <http.Request>[];
      ApiService.client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' && request.url.path.endsWith('/file')) {
          return http.Response.bytes(fileBytes, 200, headers: {'content-type': 'image/png'});
        }
        if (request.method == 'POST') {
          return http.Response(decisionBody, decisionStatus);
        }
        return http.Response('', 404);
      });
      return requests;
    }

    /// Opens the detail page from a launcher so a decision can pop it with a
    /// result, which [onResult] receives.
    Widget launcher(IdentityReview toReview, void Function(bool?) onResult) {
      return MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => IdentityReviewDetailPage(review: toReview)),
                  );
                  onResult(result);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> openDetail(WidgetTester tester) async {
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    List<http.Request> posts(List<http.Request> requests) =>
        requests.where((r) => r.method == 'POST').toList();

    testWidgets('shows each document and fetches each file', (tester) async {
      final requests = stubServer();

      await tester.pumpWidget(launcher(review(), (_) {}));
      await openDetail(tester);

      expect(find.text('National ID (front)'), findsOneWidget);
      expect(find.text('National ID (back)'), findsOneWidget);
      expect(find.byType(Image), findsNWidgets(2));
      final fetched = requests.where((r) => r.method == 'GET').map((r) => r.url.path).toList();
      expect(fetched.any((p) => p.endsWith('/documents/11/file')), isTrue);
      expect(fetched.any((p) => p.endsWith('/documents/12/file')), isTrue);
    });

    testWidgets('warns about a document that was rejected earlier and not replaced', (tester) async {
      stubServer();
      final rejected = review(documents: const [
        IdentityDocument(
          id: 11,
          docType: 'NATIONAL_ID_FRONT',
          status: 'REJECTED',
          contentType: 'image/png',
          sizeBytes: 100,
          rejectReason: 'Cropped at the edge.',
        ),
      ]);

      await tester.pumpWidget(launcher(rejected, (_) {}));
      await openDetail(tester);

      expect(find.textContaining('Rejected earlier: Cropped at the edge.'), findsOneWidget);
    });

    testWidgets('accepting asks first, then posts and closes with a result', (tester) async {
      final requests = stubServer();
      bool? result;

      await tester.pumpWidget(launcher(review(), (r) => result = r));
      await openDetail(tester);

      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      expect(find.text('Accept these documents?'), findsOneWidget);
      expect(posts(requests), isEmpty);

      await tester.tap(find.text('Yes, accept'));
      await tester.pumpAndSettle();

      final sent = posts(requests).single;
      expect(sent.url.path.endsWith('/identity/7/accept'), isTrue);
      expect(result, isTrue);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('cancelling the accept dialog sends nothing', (tester) async {
      final requests = stubServer();

      await tester.pumpWidget(launcher(review(), (_) {}));
      await openDetail(tester);

      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(posts(requests), isEmpty);
      expect(find.text('Accept'), findsOneWidget);
    });

    testWidgets('rejecting needs a reason, then posts it', (tester) async {
      final requests = stubServer();
      bool? result;

      await tester.pumpWidget(launcher(review(), (r) => result = r));
      await openDetail(tester);

      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();

      final send = find.widgetWithText(FilledButton, 'Send rejection');
      expect(tester.widget<FilledButton>(send).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '  The photo is blurry.  ');
      await tester.pump();
      expect(tester.widget<FilledButton>(send).onPressed, isNotNull);

      await tester.tap(send);
      await tester.pumpAndSettle();

      final sent = posts(requests).single;
      expect(sent.url.path.endsWith('/identity/7/reject'), isTrue);
      expect(jsonDecode(sent.body), {'reason': 'The photo is blurry.'});
      expect(result, isTrue);
    });

    testWidgets('a refused decision keeps the page open and shows the server message', (tester) async {
      stubServer(
        decisionStatus: 409,
        decisionBody: '{"error":"Some documents were rejected earlier and have not been replaced."}',
      );
      bool? result;
      var closed = false;

      await tester.pumpWidget(launcher(review(), (r) {
        result = r;
        closed = true;
      }));
      await openDetail(tester);

      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yes, accept'));
      await tester.pumpAndSettle();

      expect(find.text('Some documents were rejected earlier and have not been replaced.'), findsOneWidget);
      expect(closed, isFalse);
      expect(result, isNull);
      expect(find.text('Accept'), findsOneWidget);
    });
  });
}
