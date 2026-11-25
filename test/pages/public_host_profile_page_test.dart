import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:roost_app/pages/profile/public_host_profile_page.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/auth_service.dart';

/// HTTP is stubbed through [ApiService.client] and the token through
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

  final menu = find.byKey(const Key('host-safety-menu'));

  /// Serves an empty host (no listings, no avatar) and records every request.
  /// [blockStatus] is what the block endpoint answers.
  List<http.Request> stubHost({int blockStatus = 200}) {
    final requests = <http.Request>[];
    ApiService.client = MockClient((request) async {
      requests.add(request);
      final path = request.url.path;
      if (path.endsWith('/block')) {
        return blockStatus == 200
            ? http.Response('{"blocked":true}', 200)
            : http.Response('{"error":"nope"}', blockStatus);
      }
      if (path.contains('/api/properties/by-owner/')) return http.Response('[]', 200);
      return http.Response('{}', 200);
    });
    return requests;
  }

  Future<void> pumpHost(
    WidgetTester tester, {
    String hostId = '42',
    bool showSafetyActions = true,
  }) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: PublicHostProfilePage(
        hostId: hostId,
        hostName: 'Ada Wanjiru',
        showSafetyActions: showSafetyActions,
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('menu visibility', () {
    testWidgets('is offered on another host\'s profile', (tester) async {
      stubHost();
      await pumpHost(tester);

      expect(menu, findsOneWidget);
    });

    testWidgets('is hidden when previewing your own profile', (tester) async {
      stubHost();
      await pumpHost(tester, showSafetyActions: false);

      expect(menu, findsNothing);
    });

    testWidgets('is hidden when the host has no numeric id', (tester) async {
      stubHost();
      await pumpHost(tester, hostId: '');

      expect(menu, findsNothing);
    });
  });

  group('report', () {
    testWidgets('opens the report sheet for this host', (tester) async {
      stubHost();
      await pumpHost(tester);

      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report user'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('report-submit-button')), findsOneWidget);
      expect(find.textContaining('Ada Wanjiru'), findsWidgets);
    });
  });

  group('block', () {
    Future<void> chooseBlock(WidgetTester tester) async {
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block user'));
      await tester.pumpAndSettle();
    }

    testWidgets('asks first and sends nothing when cancelled', (tester) async {
      final requests = stubHost();
      await pumpHost(tester);

      await chooseBlock(tester);
      expect(find.text('Block Ada Wanjiru?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(requests.where((r) => r.url.path.endsWith('/block')), isEmpty);
    });

    testWidgets('blocks the host once confirmed and says so', (tester) async {
      final requests = stubHost();
      await pumpHost(tester);

      await chooseBlock(tester);
      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();

      final blocks = requests.where((r) => r.url.path.endsWith('/block')).toList();
      expect(blocks, hasLength(1));
      expect(blocks.single.method, 'POST');
      expect(blocks.single.url.path, endsWith('/api/users/42/block'));
      expect(find.text('Ada Wanjiru blocked'), findsOneWidget);
    });

    testWidgets('shows the failure and does not claim the host was blocked', (tester) async {
      stubHost(blockStatus: 500);
      await pumpHost(tester);

      await chooseBlock(tester);
      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();

      expect(find.text('Ada Wanjiru blocked'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
