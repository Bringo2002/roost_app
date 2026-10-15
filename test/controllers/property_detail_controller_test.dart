import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:roost_app/config.dart';
import 'package:roost_app/controllers/property_detail_controller.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/auth_service.dart';
import 'package:roost_app/services/location_service.dart';

/// Tests for [PropertyDetailController], which owns the property detail
/// screen's state and network calls.
///
/// HTTP goes through [ApiService.client], auth through
/// [AuthService.getTokenOverride] and location through
/// [LocationService.getCurrentPositionOverride]. All three are process-wide
/// statics, so they are reset in tearDown.
///
/// The successful *add favorite* path is deliberately not covered here: it
/// starts [ListingEventService]'s flush timer, which would outlive the test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;

  setUp(() {
    requests = [];
    AuthService.getTokenOverride = () async => 'test-token';
    LocationService.getCurrentPositionOverride = () async => null;
  });

  tearDown(() {
    ApiService.client = http.Client();
    AuthService.getTokenOverride = null;
    LocationService.getCurrentPositionOverride = null;
  });

  /// Stubs the HTTP client and records every request it receives.
  void stub(Future<http.Response> Function(http.Request request) handler) {
    ApiService.client = MockClient((request) async {
      requests.add(request);
      return handler(request);
    });
  }

  Property property({int? id = 7, double? latitude, double? longitude}) {
    return Property(
      id: id,
      title: 'Modern Apartments',
      description: 'A lovely place to call home.',
      location: 'Roysambu, Nairobi',
      price: 60000,
      bedrooms: 2,
      type: 'RENTAL',
      landlordPhone: '+254712345678',
      available: true,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Position position(double latitude, double longitude) {
    return Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime(2026, 10, 16),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  group('distanceLabel', () {
    test('is null until the user position is known', () {
      final controller = PropertyDetailController(
        property: property(latitude: -1.29, longitude: 36.82),
      );

      expect(controller.distanceLabel, isNull);
    });

    test('is null when the property has no coordinates', () {
      final controller = PropertyDetailController(property: property())
        ..userPosition = position(-1.29, 36.82);

      expect(controller.distanceLabel, isNull);
    });

    test('says walk for a short distance', () {
      final controller = PropertyDetailController(
        property: property(latitude: -1.2900, longitude: 36.8200),
      )..userPosition = position(-1.2860, 36.8200);

      expect(
        controller.distanceLabel,
        matches(RegExp(r'^\d+ m away · ~\d+ min walk$')),
      );
    });

    test('says drive for a longer distance', () {
      final controller = PropertyDetailController(
        property: property(latitude: -1.2900, longitude: 36.8200),
      )..userPosition = position(-1.2600, 36.8200);

      expect(
        controller.distanceLabel,
        matches(RegExp(r'^\d+\.\d km away · ~\d+ min drive$')),
      );
    });

    test('never shows less than one minute', () {
      final controller = PropertyDetailController(
        property: property(latitude: -1.2900, longitude: 36.8200),
      )..userPosition = position(-1.2901, 36.8200);

      expect(controller.distanceLabel, contains('~1 min walk'));
    });
  });

  group('toggleFavorite', () {
    test('does nothing for a property without an id', () async {
      stub((_) async => http.Response('{}', 200));
      final controller = PropertyDetailController(property: property(id: null));

      await controller.toggleFavorite();

      expect(requests, isEmpty);
      expect(controller.isFavorite, isFalse);
    });

    test('flips optimistically, then rolls back when the request fails', () async {
      stub((request) async {
        if (request.method == 'GET') return http.Response('[]', 200);
        return http.Response('{"error":"nope"}', 500);
      });
      final controller = PropertyDetailController(property: property());
      final seen = <bool>[];
      controller.addListener(() => seen.add(controller.isFavorite));

      await controller.toggleFavorite();

      expect(seen, [true, false]);
      expect(controller.isFavorite, isFalse);
    });

    test('ignores a second tap while the first is still in flight', () async {
      final save = Completer<http.Response>();
      stub((request) {
        if (request.method == 'GET') {
          return Future.value(http.Response('[]', 200));
        }
        return save.future;
      });
      final controller = PropertyDetailController(property: property());
      final seen = <bool>[];
      controller.addListener(() => seen.add(controller.isFavorite));

      final first = controller.toggleFavorite();
      await controller.toggleFavorite();
      save.complete(http.Response('boom', 500));
      await first;

      expect(requests.where((r) => r.method == 'POST'), hasLength(1));
      expect(seen, [true, false]);
    });
  });

  group('submitCommunityCheck', () {
    test('posts every answer and marks the check submitted', () async {
      stub((_) async => http.Response('{}', 200));
      final controller = PropertyDetailController(property: property());
      var notified = 0;
      controller.addListener(() => notified++);

      await controller.submitCommunityCheck(
        visited: true,
        photosAccurate: true,
        locationAccurate: false,
        priceAccurate: true,
        wouldRecommend: false,
      );

      final request = requests.single;
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        '${AppConfig.baseUrl}/api/properties/7/community-check',
      );
      expect(jsonDecode(request.body), {
        'visited': true,
        'photosAccurate': true,
        'locationAccurate': false,
        'priceAccurate': true,
        'wouldRecommend': false,
      });
      expect(controller.communityCheckSubmitted, isTrue);
      expect(notified, 1);
    });

    test('sends false for every answer when the renter has not visited', () async {
      stub((_) async => http.Response('{}', 200));
      final controller = PropertyDetailController(property: property());

      await controller.submitCommunityCheck(
        visited: false,
        photosAccurate: true,
        locationAccurate: true,
        priceAccurate: true,
        wouldRecommend: true,
      );

      expect(jsonDecode(requests.single.body), {
        'visited': false,
        'photosAccurate': false,
        'locationAccurate': false,
        'priceAccurate': false,
        'wouldRecommend': false,
      });
    });

    test('throws and stays unsubmitted when the request fails', () async {
      stub((_) async => http.Response('{"error":"nope"}', 500));
      final controller = PropertyDetailController(property: property());

      await expectLater(
        controller.submitCommunityCheck(
          visited: true,
          photosAccurate: true,
          locationAccurate: true,
          priceAccurate: true,
          wouldRecommend: true,
        ),
        throwsA(isA<ApiException>()),
      );

      expect(controller.communityCheckSubmitted, isFalse);
    });
  });

  group('reports', () {
    test('reportProperty posts the reason', () async {
      stub((_) async => http.Response('{}', 200));
      final controller = PropertyDetailController(property: property());

      await controller.reportProperty('Misleading photos');

      final request = requests.single;
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        '${AppConfig.baseUrl}/api/properties/7/report',
      );
      expect(jsonDecode(request.body), {'reason': 'Misleading photos'});
    });

    test('reportViewingFee posts the fixed reason and the detail', () async {
      stub((_) async => http.Response('{}', 200));
      final controller = PropertyDetailController(property: property());

      await controller.reportViewingFee('Asked for KES 500 at the gate');

      expect(jsonDecode(requests.single.body), {
        'reason': 'Viewing fee charged',
        'detail': 'Asked for KES 500 at the gate',
      });
    });

    test('reports surface the failure to the caller', () async {
      stub((_) async => http.Response('{"error":"nope"}', 500));
      final controller = PropertyDetailController(property: property());

      await expectLater(
        controller.reportProperty('Spam'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('init', () {
    test('loads favorite state, eligibility and the user position', () async {
      stub((request) async {
        final path = request.url.path;
        if (path.endsWith('/saved')) return http.Response('[]', 200);
        if (path.endsWith('/community-check/eligible')) {
          return http.Response('{"eligible": true}', 200);
        }
        return http.Response('{}', 200);
      });
      LocationService.getCurrentPositionOverride =
          () async => position(-1.29, 36.82);
      final controller = PropertyDetailController(property: property());

      await controller.init();

      expect(controller.isFavorite, isFalse);
      expect(controller.communityCheckEligible, isTrue);
      expect(controller.userPosition, isNotNull);
    });

    test('hides the community check when the eligibility call fails', () async {
      stub((request) async {
        final path = request.url.path;
        if (path.endsWith('/saved')) return http.Response('[]', 200);
        if (path.endsWith('/community-check/eligible')) {
          return http.Response('{"error":"nope"}', 500);
        }
        return http.Response('{}', 200);
      });
      final controller = PropertyDetailController(property: property());

      await controller.init();

      expect(controller.communityCheckEligible, isFalse);
    });

    test('hides the community check when eligible is not true', () async {
      stub((request) async {
        final path = request.url.path;
        if (path.endsWith('/saved')) return http.Response('[]', 200);
        if (path.endsWith('/community-check/eligible')) {
          return http.Response('{"eligible": false}', 200);
        }
        return http.Response('{}', 200);
      });
      final controller = PropertyDetailController(property: property());

      await controller.init();

      expect(controller.communityCheckEligible, isFalse);
    });

    test('makes no API calls for a property without an id', () async {
      stub((_) async => http.Response('{}', 200));
      final controller = PropertyDetailController(property: property(id: null));

      await controller.init();

      expect(requests, isEmpty);
    });
  });
}
