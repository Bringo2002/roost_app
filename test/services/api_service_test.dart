import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:roost_app/config.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/auth_service.dart';

/// Characterization tests for [ApiService]: they pin what the client does
/// today (URL building, headers, JSON handling, error mapping) so later
/// changes to its error handling can be made safely.
///
/// HTTP goes through [ApiService.client] and auth through
/// [AuthService.getTokenOverride]. Both are process-wide statics, so they
/// are reset in tearDown.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AuthService.getTokenOverride = () async => 'test-token';
  });

  tearDown(() {
    ApiService.client = http.Client();
    AuthService.getTokenOverride = null;
  });

  /// Stubs the client with one canned response.
  void respondWith(int status, [String body = '']) {
    ApiService.client = MockClient((_) async => http.Response(body, status));
  }

  /// Stubs the client with an empty JSON 200 and returns the list that
  /// records every request it receives.
  List<http.Request> capture() {
    final requests = <http.Request>[];
    ApiService.client = MockClient((request) async {
      requests.add(request);
      return http.Response('{}', 200);
    });
    return requests;
  }

  Matcher apiError(String message) => throwsA(
        isA<ApiException>().having((e) => e.message, 'message', message),
      );

  group('request building', () {
    test('GET targets the base URL with JSON and bearer-token headers', () async {
      final requests = capture();

      await ApiService.get('/api/ping');

      final request = requests.single;
      expect(request.method, 'GET');
      expect(request.url.toString(), '${AppConfig.baseUrl}/api/ping');
      expect(request.headers['Authorization'], 'Bearer test-token');
      expect(request.headers['Content-Type'], contains('application/json'));
    });

    test('omits Authorization when there is no token', () async {
      AuthService.getTokenOverride = () async => null;
      final requests = capture();

      await ApiService.get('/api/ping');

      expect(requests.single.headers.containsKey('Authorization'), isFalse);
    });

    test('POST sends the body as JSON', () async {
      final requests = capture();

      await ApiService.post('/api/things', {'name': 'Roost', 'count': 2});

      expect(requests.single.method, 'POST');
      expect(jsonDecode(requests.single.body), {'name': 'Roost', 'count': 2});
    });

    test('POST without a body sends none', () async {
      final requests = capture();

      await ApiService.post('/api/things');

      expect(requests.single.body, isEmpty);
    });

    test('PUT, PATCH and DELETE use their own verbs', () async {
      final requests = capture();

      await ApiService.put('/api/a', {'k': 1});
      await ApiService.patch('/api/b', {'k': 2});
      await ApiService.delete('/api/c');

      expect(requests.map((r) => r.method), ['PUT', 'PATCH', 'DELETE']);
      expect(requests.map((r) => r.url.path), ['/api/a', '/api/b', '/api/c']);
    });
  });

  group('successful responses', () {
    test('decodes a JSON object', () async {
      respondWith(200, '{"id": 7, "title": "Loft"}');

      expect(await ApiService.get('/api/x'), {'id': 7, 'title': 'Loft'});
    });

    test('decodes a JSON array', () async {
      respondWith(200, '[1, 2, 3]');

      expect(await ApiService.get('/api/x'), [1, 2, 3]);
    });

    test('returns null for an empty 200 body', () async {
      respondWith(200);

      expect(await ApiService.get('/api/x'), isNull);
    });

    test('returns null for a 204', () async {
      respondWith(204);

      expect(await ApiService.delete('/api/x'), isNull);
    });
  });

  group('error responses other than 401 and 403', () {
    test('uses the "error" field as the message', () async {
      respondWith(400, '{"error": "Bad input"}');

      await expectLater(ApiService.get('/api/x'), apiError('Bad input'));
    });

    test('falls back to the "message" field', () async {
      respondWith(422, '{"message": "Invalid price"}');

      await expectLater(ApiService.get('/api/x'), apiError('Invalid price'));
    });

    test('prefers "error" over "message"', () async {
      respondWith(400, '{"error": "first", "message": "second"}');

      await expectLater(ApiService.get('/api/x'), apiError('first'));
    });

    test('names the status when the body is empty', () async {
      respondWith(500);

      await expectLater(
        ApiService.get('/api/x'),
        apiError('Request failed with status: 500'),
      );
    });

    test('names the status when the JSON has neither field', () async {
      respondWith(404, '{}');

      await expectLater(
        ApiService.get('/api/x'),
        apiError('Request failed with status: 404'),
      );
    });

    // Current behavior, pinned so a change to it is deliberate: a body that
    // is not JSON is shown to the user verbatim.
    test('uses a non-JSON body verbatim as the message', () async {
      respondWith(500, 'Upstream exploded');

      await expectLater(ApiService.get('/api/x'), apiError('Upstream exploded'));
    });
  });

  group('403 responses', () {
    test('uses the "error" field', () async {
      respondWith(403, '{"error": "Landlords only"}');

      await expectLater(ApiService.get('/api/x'), apiError('Landlords only'));
    });

    test('falls back to the "message" field', () async {
      respondWith(403, '{"message": "Not your listing"}');

      await expectLater(ApiService.get('/api/x'), apiError('Not your listing'));
    });

    test('uses the generic permission message when the body is empty', () async {
      respondWith(403);

      await expectLater(
        ApiService.get('/api/x'),
        apiError('You do not have permission to perform this action.'),
      );
    });

    test('uses the generic permission message when the JSON has no message', () async {
      respondWith(403, '{}');

      await expectLater(
        ApiService.get('/api/x'),
        apiError('You do not have permission to perform this action.'),
      );
    });

    // Current behavior, pinned so a change to it is deliberate.
    test('uses a non-JSON body verbatim as the message', () async {
      respondWith(403, 'Forbidden by gateway');

      await expectLater(
        ApiService.get('/api/x'),
        apiError('Forbidden by gateway'),
      );
    });
  });
}
