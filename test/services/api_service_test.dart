import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
    AuthService.refreshTokenOverride = null;
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

  group('statusCode', () {
    Matcher apiErrorWithStatus(int status) => throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', status),
        );

    test('is set on a 4xx response', () async {
      respondWith(404, '{"error": "Property not found"}');

      await expectLater(ApiService.get('/api/x'), apiErrorWithStatus(404));
    });

    test('is set on a 5xx response', () async {
      respondWith(503);

      await expectLater(ApiService.get('/api/x'), apiErrorWithStatus(503));
    });

    test('is set on a 403 response', () async {
      respondWith(403, '{"error": "Landlords only"}');

      await expectLater(ApiService.get('/api/x'), apiErrorWithStatus(403));
    });

    test('is null when no response arrived', () async {
      ApiService.client = MockClient((_) async => throw const SocketException('offline'));

      await expectLater(
        ApiService.get('/api/x'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', isNull)),
      );
    });
  });

  group('transport failures', () {
    test('maps SocketException to "No internet connection"', () async {
      ApiService.client = MockClient((_) async => throw const SocketException('offline'));

      await expectLater(ApiService.get('/api/x'), apiError('No internet connection'));
    });

    test('maps TimeoutException to a timeout message', () async {
      ApiService.client = MockClient((_) async => throw TimeoutException('slow'));

      await expectLater(
        ApiService.get('/api/x'),
        apiError('Request timed out. Please try again.'),
      );
    });

    test('maps any other client error to a generic message', () async {
      ApiService.client = MockClient((_) async => throw http.ClientException('boom'));

      await expectLater(
        ApiService.get('/api/x'),
        apiError('Something went wrong. Please try again.'),
      );
    });

    test('maps an undecodable 200 body to a generic message', () async {
      respondWith(200, 'not json');

      await expectLater(
        ApiService.get('/api/x'),
        apiError('Something went wrong. Please try again.'),
      );
    });
  });

  group('401 handling', () {
    test('refreshes the token and retries once with the new one', () async {
      var token = 'old-token';
      AuthService.getTokenOverride = () async => token;
      var refreshCalls = 0;
      AuthService.refreshTokenOverride = () async {
        refreshCalls++;
        token = 'new-token';
        return true;
      };
      final seen = <String?>[];
      ApiService.client = MockClient((request) async {
        seen.add(request.headers['Authorization']);
        return seen.length == 1 ? http.Response('', 401) : http.Response('{"ok": true}', 200);
      });

      expect(await ApiService.get('/api/me'), {'ok': true});
      expect(refreshCalls, 1);
      expect(seen, ['Bearer old-token', 'Bearer new-token']);
    });

    test('does not try to refresh for other error statuses', () async {
      var refreshCalls = 0;
      AuthService.refreshTokenOverride = () async {
        refreshCalls++;
        return true;
      };
      respondWith(500, '{"error": "down"}');

      await expectLater(ApiService.get('/api/x'), apiError('down'));
      expect(refreshCalls, 0);
    });
  });

  test('confirmUpload never throws, even when the request fails', () async {
    respondWith(500, '{"error": "nope"}');

    await expectLater(
      ApiService.confirmUpload(
        contentHash: 'abc',
        publicUrl: 'https://cdn.example/p.jpg',
        key: 'photos/p.jpg',
        contentType: 'image/jpeg',
        sizeBytes: 1,
      ),
      completes,
    );
  });

  group('toUserMessage', () {
    test('strips the Exception prefix', () {
      expect(Exception('boom').toUserMessage(), 'boom');
    });

    test('strips the FormatException prefix', () {
      expect(const FormatException('bad input').toUserMessage(), 'bad input');
    });

    test('passes an ApiException message through unchanged', () {
      expect(ApiException('No internet connection').toUserMessage(), 'No internet connection');
    });

    test('falls back when the text is empty', () {
      expect(''.toUserMessage(), 'Something went wrong. Please try again.');
    });

    test('falls back for an object with no readable text', () {
      expect(Object().toUserMessage(), 'Something went wrong. Please try again.');
    });

    test('uses a custom fallback when given one', () {
      expect(''.toUserMessage('Try later'), 'Try later');
    });
  });
}
