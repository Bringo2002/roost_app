import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:roost_app/config.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/auth_service.dart';

/// [ApiService.getBytes] fetches a stored document: a binary body that must
/// reach the caller untouched, with the same auth and error handling as the
/// JSON calls.
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

  test('returns the body bytes untouched, even when they are not valid JSON or text', () async {
    final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x80]);
    ApiService.client = MockClient(
      (_) async => http.Response.bytes(bytes, 200, headers: {'content-type': 'image/jpeg'}),
    );

    final result = await ApiService.getBytes('/api/file');

    expect(result, bytes);
  });

  test('is a GET to the base URL carrying the bearer token', () async {
    final requests = <http.Request>[];
    ApiService.client = MockClient((request) async {
      requests.add(request);
      return http.Response.bytes([1, 2, 3], 200);
    });

    await ApiService.getBytes('/api/file');

    final request = requests.single;
    expect(request.method, 'GET');
    expect(request.url.toString(), '${AppConfig.baseUrl}/api/file');
    expect(request.headers['Authorization'], 'Bearer test-token');
  });

  test('a 403 throws an ApiException carrying the status', () async {
    ApiService.client = MockClient((_) async => http.Response('', 403));

    expect(
      ApiService.getBytes('/api/file'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403)),
    );
  });

  test('a JSON error body surfaces its message', () async {
    ApiService.client = MockClient(
      (_) async => http.Response('{"error":"Document not found."}', 404),
    );

    expect(
      ApiService.getBytes('/api/file'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.message, 'message', 'Document not found.')
            .having((e) => e.statusCode, 'statusCode', 404),
      ),
    );
  });

  test('a 503 from unavailable storage throws an ApiException carrying the status', () async {
    ApiService.client = MockClient(
      (_) async => http.Response('{"error":"Document storage is not available right now."}', 503),
    );

    expect(
      ApiService.getBytes('/api/file'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 503)),
    );
  });
}
