import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:roost_app/pages/landlord/landlord_dashboard_page.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/auth_service.dart';

Map<String, dynamic> _item({required int id, String title = 'Listing', String status = 'PUBLISHED'}) {
  return {
    'id': id,
    'title': title,
    'location': 'Nairobi',
    'price': 25000,
    'bedrooms': 1,
    'type': 'RENTAL',
    'available': true,
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

http.Response _json(Object body) =>
    http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});

/// A full-height drag on the scroll view, large enough to reach (and
/// clamp at) the bottom regardless of exact content height.
Future<void> _dragToBottom(WidgetTester tester) async {
  await tester.drag(find.byType(CustomScrollView), const Offset(0, -20000));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    AuthService.getTokenOverride = () async => 'fake-token';
  });

  tearDown(() {
    AuthService.getTokenOverride = null;
    ApiService.client = http.Client();
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  testWidgets('scrolling near the bottom fetches the next page', (tester) async {
    final requestedPages = <String?>[];
    ApiService.client = MockClient((request) async {
      requestedPages.add(request.url.queryParameters['page']);
      if (request.url.queryParameters['page'] == '0') {
        return _json(
          _page(
            items: List.generate(15, (i) => _item(id: i, title: 'Page0 Item $i')),
            hasNext: true,
            total: 16,
            available: 16,
          ),
        );
      }
      return _json(_page(items: [_item(id: 99, title: 'Page1 Item')], hasNext: false, total: 16, available: 16));
    });

    await tester.pumpWidget(wrap(const LandlordDashboardPage()));
    await tester.pumpAndSettle();

    expect(find.text('Page1 Item'), findsNothing);
    await _dragToBottom(tester);

    expect(find.text('Page1 Item'), findsOneWidget);
    expect(requestedPages, ['0', '1']);
  });

  testWidgets('hasNext false means scrolling never requests a second page', (tester) async {
    var getCallCount = 0;
    ApiService.client = MockClient((request) async {
      getCallCount++;
      return _json(
        _page(items: [_item(id: 1, title: 'Only Item')], hasNext: false, total: 1, available: 1),
      );
    });

    await tester.pumpWidget(wrap(const LandlordDashboardPage()));
    await tester.pumpAndSettle();

    await _dragToBottom(tester);
    await _dragToBottom(tester);

    expect(getCallCount, 1);
  });

  testWidgets('switching the filter chip resets to page 0 with the new filter and replaces the rows', (
    tester,
  ) async {
    final requestedFilters = <String?>[];
    ApiService.client = MockClient((request) async {
      requestedFilters.add(request.url.queryParameters['filter']);
      if (request.url.queryParameters['filter'] == 'DRAFT') {
        return _json(
          _page(items: [_item(id: 2, title: 'Draft Item', status: 'DRAFT')], total: 2, drafts: 1, available: 1),
        );
      }
      return _json(_page(items: [_item(id: 1, title: 'All Item')], total: 2, drafts: 1, available: 1));
    });

    await tester.pumpWidget(wrap(const LandlordDashboardPage()));
    await tester.pumpAndSettle();
    expect(find.text('All Item'), findsOneWidget);

    await tester.tap(find.text('Drafts (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Draft Item'), findsOneWidget);
    expect(find.text('All Item'), findsNothing);
    expect(requestedFilters, ['ALL', 'DRAFT']);
  });

  testWidgets('stats header and chip badges reflect server-side counts, not just the loaded page', (tester) async {
    ApiService.client = MockClient((request) async {
      // Only one row comes back on this page, but the portfolio has far
      // more -- the header/chips must show the server's totals, since
      // `_myListings` only ever holds the pages scrolled through so far.
      return _json(
        _page(
          items: [_item(id: 1, title: 'One Of Many')],
          hasNext: true,
          total: 47,
          drafts: 5,
          available: 30,
          rented: 12,
          verified: 20,
        ),
      );
    });

    await tester.pumpWidget(wrap(const LandlordDashboardPage()));
    await tester.pumpAndSettle();

    expect(find.text('47'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('All (47)'), findsOneWidget);
    expect(find.text('Drafts (5)'), findsOneWidget);
    expect(find.text('Available (30)'), findsOneWidget);
    expect(find.text('Rented (12)'), findsOneWidget);
  });
}
