import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/auth_service.dart';
import 'package:roost_app/services/property_draft_service.dart';

/// HTTP goes through [ApiService.client] and auth through
/// [AuthService.getTokenOverride]; both are process-wide statics, so they are
/// reset in tearDown.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AuthService.getTokenOverride = () async => 'test-token';
  });

  tearDown(() {
    ApiService.client = http.Client();
    AuthService.getTokenOverride = null;
  });

  /// Routes PUT and POST to canned responses (an empty JSON 200 when not
  /// given) and returns the list that records every request received.
  List<http.Request> stub({http.Response? put, http.Response? post}) {
    final requests = <http.Request>[];
    ApiService.client = MockClient((request) async {
      requests.add(request);
      final response = request.method == 'PUT' ? put : post;
      return response ?? http.Response('{}', 200);
    });
    return requests;
  }

  /// "METHOD /path" for each recorded request, in order.
  List<String> calls(List<http.Request> requests) =>
      requests.map((r) => '${r.method} ${r.url.path}').toList();

  group('PropertyDraftService.save', () {
    test('creates the property when there is no draft yet', () async {
      final requests = stub(post: http.Response('{"id": 41}', 201));

      final id = await PropertyDraftService.save(null, {'title': 'Loft'});

      expect(id, 41);
      expect(calls(requests), ['POST /api/properties']);
      expect(jsonDecode(requests.single.body), {'title': 'Loft'});
    });

    test('updates an existing draft in place', () async {
      final requests = stub();

      final id = await PropertyDraftService.save(7, {'title': 'Loft'});

      expect(id, 7);
      expect(calls(requests), ['PUT /api/properties/7']);
    });

    test('creates a new property when the draft no longer exists', () async {
      final requests = stub(
        put: http.Response('{"error": "Property not found with id: 7"}', 404),
        post: http.Response('{"id": 8}', 201),
      );

      final id = await PropertyDraftService.save(7, {'title': 'Loft'});

      expect(id, 8);
      expect(calls(requests), ['PUT /api/properties/7', 'POST /api/properties']);
    });

    test('also recovers when the 404 has no readable body', () async {
      final requests = stub(
        put: http.Response('', 404),
        post: http.Response('{"id": 8}', 201),
      );

      final id = await PropertyDraftService.save(7, {'title': 'Loft'});

      expect(id, 8);
      expect(calls(requests), ['PUT /api/properties/7', 'POST /api/properties']);
    });

    test('rethrows other failures without creating a duplicate', () async {
      final requests = stub(put: http.Response('{"error": "Unauthorized"}', 403));

      await expectLater(
        PropertyDraftService.save(7, {'title': 'Loft'}),
        throwsA(isA<ApiException>()),
      );
      expect(calls(requests), ['PUT /api/properties/7']);
    });

    test('returns null when the create response carries no id', () async {
      stub(post: http.Response('{}', 201));

      expect(await PropertyDraftService.save(null, {'title': 'Loft'}), isNull);
    });
  });
}
