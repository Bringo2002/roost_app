import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:roost_app/pages/landlord/landlord_dashboard_page.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/auth_service.dart';

/// One slim v2 my-listings item, matching PropertyListItemDto's shape
/// (see roost_app/lib/models/property.dart's fromJson -- fields this
/// omits fall back to their documented defaults).
Map<String, dynamic> _item({
  required int id,
  String title = 'Listing',
  String status = 'PUBLISHED',
  bool available = true,
}) {
  return {
    'id': id,
    'title': title,
    'location': 'Nairobi',
    'price': 25000,
    'bedrooms': 1,
    'type': 'RENTAL',
    'available': available,
    'imageUrl': null,
    'verified': false,
    'gpsVerified': false,
    'status': status,
    'listedAt': null,
    'landlordEndorsed': false,
    'endorsementToken': null,
    'ownerVerifyName': null,
    'ownerVerifyPhone': null,
    'managerRole': 'LANDLORD',
  };
}

/// One page of the MyListingsPageResponse envelope.
Map<String, dynamic> _page({
  required List<Map<String, dynamic>> items,
  int page = 0,
  bool hasNext = false,
  int total = 0,
  int drafts = 0,
  int available = 0,
  int rented = 0,
  int verified = 0,
}) {
  return {
    'items': items,
    'page': page,
    'size': 20,
    'hasNext': hasNext,
    'counts': {
      'total': total,
      'drafts': drafts,
      'available': available,
      'rented': rented,
      'verified': verified,
    },
  };
}

http.Response _json(Object body, [int statusCode = 200]) =>
    http.Response(jsonEncode(body), statusCode, headers: {'content-type': 'application/json'});

void main() {
  setUp(() {
    // ApiService._getHeaders() always calls AuthService.getToken() first;
    // without this it would hit FlutterSecureStorage's real platform
    // channel and throw MissingPluginException before any mocked HTTP
    // call is ever reached.
    AuthService.getTokenOverride = () async => 'fake-token';
  });

  tearDown(() {
    // Don't let one test's stub leak into the next.
    AuthService.getTokenOverride = null;
    ApiService.client = http.Client();
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  testWidgets('loads the first page and renders a listing', (tester) async {
    ApiService.client = MockClient((request) async {
      expect(request.url.path, '/api/v2/properties/my-listings');
      expect(request.url.queryParameters['page'], '0');
      expect(request.url.queryParameters['filter'], 'ALL');
      return _json(_page(items: [_item(id: 1, title: 'Cozy Bedsitter')], total: 1, available: 1));
    });

    await tester.pumpWidget(wrap(const LandlordDashboardPage()));
    await tester.pumpAndSettle();

    expect(find.text('Cozy Bedsitter'), findsOneWidget);
  });

  testWidgets('shows the retry error state when the first page fails', (tester) async {
    ApiService.client = MockClient((request) async => http.Response('', 500));

    await tester.pumpWidget(wrap(const LandlordDashboardPage()));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load your listings"), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
  });

  testWidgets('tapping Retry reloads after a failed first page', (tester) async {
    var callCount = 0;
    ApiService.client = MockClient((request) async {
      callCount++;
      if (callCount == 1) return http.Response('', 500);
      return _json(_page(items: [_item(id: 1, title: 'Recovered')], total: 1, available: 1));
    });

    await tester.pumpWidget(wrap(const LandlordDashboardPage()));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load your listings"), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Recovered'), findsOneWidget);
    expect(callCount, 2);
  });

  testWidgets('toggling an unavailable listing back on sends the PATCH body and flips the switch with no reload', (
    tester,
  ) async {
    var getCallCount = 0;
    Map<String, dynamic>? patchedBody;
    ApiService.client = MockClient((request) async {
      if (request.method == 'GET') {
        getCallCount++;
        return _json(_page(items: [_item(id: 1, available: false)], total: 1, rented: 1));
      }
      if (request.method == 'PATCH' && request.url.path.endsWith('/availability')) {
        patchedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _json({});
      }
      fail('unexpected request: ${request.method} ${request.url}');
    });

    await tester.pumpWidget(wrap(const LandlordDashboardPage()));
    await tester.pumpAndSettle();

    // Starting from `available: false` skips the "Mark as Rented?"
    // confirmation dialog entirely (that only guards turning availability
    // OFF) -- this test is specifically about the optimistic-update path,
    // the dialog-gating behavior is covered separately below.
    final switchFinder = find.byType(Switch);
    expect(tester.widget<Switch>(switchFinder).value, isFalse);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(patchedBody, {'available': true});
    expect(tester.widget<Switch>(switchFinder).value, isTrue);
    // Optimistic: the toggle must not trigger a full-list reload.
    expect(getCallCount, 1);
  });

  testWidgets('turning availability off asks for confirmation; Cancel sends no request', (tester) async {
    ApiService.client = MockClient((request) async {
      if (request.method == 'GET') {
        return _json(_page(items: [_item(id: 1, available: true)], total: 1, available: 1));
      }
      fail('unexpected request: ${request.method} ${request.url}');
    });

    await tester.pumpWidget(wrap(const LandlordDashboardPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('Mark as Rented?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('confirming "Mark as Rented" sends the PATCH; a failed toggle reverts and shows a snackbar', (
    tester,
  ) async {
    ApiService.client = MockClient((request) async {
      if (request.method == 'GET') {
        return _json(_page(items: [_item(id: 1, available: true)], total: 1, available: 1));
      }
      if (request.method == 'PATCH') return http.Response('server error', 500);
      fail('unexpected request: ${request.method} ${request.url}');
    });

    await tester.pumpWidget(wrap(const LandlordDashboardPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as Rented'));
    await tester.pumpAndSettle();

    // Reverted back to available after the PATCH failed.
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(find.textContaining('Failed'), findsOneWidget);
  });

  testWidgets('deleting a listing confirms, sends DELETE, and removes the row', (tester) async {
    var deleteCalled = false;
    ApiService.client = MockClient((request) async {
      if (request.method == 'GET') {
        return _json(_page(items: [_item(id: 1, title: 'To Be Deleted')], total: 1, available: 1));
      }
      if (request.method == 'DELETE') {
        deleteCalled = true;
        return _json({});
      }
      fail('unexpected request: ${request.method} ${request.url}');
    });

    await tester.pumpWidget(wrap(const LandlordDashboardPage()));
    await tester.pumpAndSettle();
    expect(find.text('To Be Deleted'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Delete Listing'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(deleteCalled, isTrue);
    expect(find.text('To Be Deleted'), findsNothing);
  });
}
