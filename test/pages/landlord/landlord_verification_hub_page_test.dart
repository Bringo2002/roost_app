import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:roost_app/pages/landlord/landlord_verification_hub_page.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/auth_service.dart';
import 'package:roost_app/services/location_service.dart';

/// v1 /api/properties/my-listings returns a bare JSON array of full
/// PropertyResponseDto-shaped objects (not the v2 slim-item/envelope
/// shape the dashboard uses) -- this page still calls v1, deliberately
/// (see the review notes for why migrating it to v2 isn't a drop-in win).
Map<String, dynamic> _property({
  required int id,
  String title = 'Listing',
  bool gpsVerified = false,
  bool verified = false,
}) {
  return {
    'id': id,
    'title': title,
    'location': 'Nairobi',
    'price': 25000,
    'bedrooms': 1,
    'type': 'RENTAL',
    'landlordPhone': '+254700000000',
    'available': true,
    'status': 'PUBLISHED',
    'verified': verified,
    'gpsVerified': gpsVerified,
    'documentVerified': false,
    'imageUrls': <String>[],
  };
}

http.Response _json(Object body) =>
    http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});

/// A plausible, internally-consistent device fix for Nairobi. The exact
/// field set a `geolocator` Position needs couldn't be checked against
/// the real package source in this environment (no offline pub cache) --
/// if this line doesn't compile, that's the one thing to fix by hand
/// rather than treat as a sign anything else here is wrong.
Position _fakePosition() => Position(
  latitude: -1.286389,
  longitude: 36.817223,
  timestamp: DateTime(2026),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

/// The hub is a scroll view and its "Verify GPS On-Site" button sits below
/// the default 800x600 test viewport, so a bare `tap` misses it. Scroll it
/// into view first, then tap.
Future<void> _tapVerifyGps(WidgetTester tester) async {
  final button = find.text('Verify GPS On-Site');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    AuthService.getTokenOverride = () async => 'fake-token';
  });

  tearDown(() {
    AuthService.getTokenOverride = null;
    LocationService.getCurrentPositionOverride = null;
    ApiService.client = http.Client();
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  testWidgets('loads properties and renders a verification row', (tester) async {
    ApiService.client = MockClient((request) async {
      expect(request.url.path, '/api/properties/my-listings');
      return _json([_property(id: 1, title: 'Cozy Bedsitter')]);
    });

    await tester.pumpWidget(wrap(const LandlordVerificationHubPage()));
    await tester.pumpAndSettle();

    expect(find.text('Cozy Bedsitter'), findsOneWidget);
    expect(find.text('Verify GPS On-Site'), findsOneWidget);
  });

  testWidgets('verifying GPS posts the coordinates and updates locally, with no second GET', (tester) async {
    LocationService.getCurrentPositionOverride = () async => _fakePosition();
    var getCallCount = 0;
    Map<String, dynamic>? postedBody;

    ApiService.client = MockClient((request) async {
      if (request.method == 'GET') {
        getCallCount++;
        return _json([_property(id: 1, title: 'Cozy Bedsitter')]);
      }
      if (request.method == 'POST' && request.url.path.endsWith('/verify-gps')) {
        postedBody = jsonDecode(request.body) as Map<String, dynamic>;
        // The real endpoint returns the updated listing (PropertyResponseDto).
        return _json(_property(id: 1, title: 'Cozy Bedsitter', gpsVerified: true));
      }
      fail('unexpected request: ${request.method} ${request.url}');
    });

    await tester.pumpWidget(wrap(const LandlordVerificationHubPage()));
    await tester.pumpAndSettle();

    await _tapVerifyGps(tester);

    expect(postedBody, {'latitude': -1.286389, 'longitude': 36.817223});
    // The button is only shown `if (!property.gpsVerified)` -- its
    // disappearance is direct evidence the local update applied.
    expect(find.text('Verify GPS On-Site'), findsNothing);
    // The actual regression this guards: verifying GPS must not trigger
    // a full-portfolio reload just to reflect one property's change.
    expect(getCallCount, 1);
  });

  testWidgets('no location available shows a snackbar and never calls the API', (tester) async {
    LocationService.getCurrentPositionOverride = () async => null;
    var postCalled = false;

    ApiService.client = MockClient((request) async {
      if (request.method == 'GET') return _json([_property(id: 1, title: 'Cozy Bedsitter')]);
      postCalled = true;
      return _json({});
    });

    await tester.pumpWidget(wrap(const LandlordVerificationHubPage()));
    await tester.pumpAndSettle();

    await _tapVerifyGps(tester);

    expect(find.textContaining('Could not obtain current GPS position'), findsOneWidget);
    expect(postCalled, isFalse);
    // The button must still be offered -- nothing was verified.
    expect(find.text('Verify GPS On-Site'), findsOneWidget);
  });

  testWidgets('verifying GPS adopts the server-computed verified flag from the response', (tester) async {
    LocationService.getCurrentPositionOverride = () async => _fakePosition();

    ApiService.client = MockClient((request) async {
      if (request.method == 'GET') return _json([_property(id: 1, title: 'Cozy Bedsitter')]);
      // GPS was the last missing proof, so the server flips `verified` too.
      return _json(_property(id: 1, title: 'Cozy Bedsitter', gpsVerified: true, verified: true));
    });

    await tester.pumpWidget(wrap(const LandlordVerificationHubPage()));
    await tester.pumpAndSettle();
    expect(find.text('0/1 Verified'), findsOneWidget);

    await _tapVerifyGps(tester);

    // A local gpsVerified flip alone would leave this at 0/1.
    expect(find.text('1/1 Verified'), findsOneWidget);
  });
}
