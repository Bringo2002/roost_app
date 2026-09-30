import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:roost_app/config.dart';
import 'package:roost_app/models/presigned_upload.dart';
import 'package:roost_app/services/auth_service.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

extension ExceptionFormatting on Object {
  String toUserMessage([String fallback = 'Something went wrong. Please try again.']) {
    final str = toString().trim();
    if (str.isEmpty) return fallback;
    final cleaned = str
        .replaceAll(RegExp(r'^(Exception|ApiException|FormatException):\s*'), '')
        .trim();
    if (cleaned.contains('Instance of') || cleaned.isEmpty) {
      return fallback;
    }
    return cleaned;
  }
}

class ApiService {
  static const Duration _timeoutDuration = Duration(seconds: 10);

  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<dynamic> _safeRequest(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(_timeoutDuration);
      if (response.statusCode == 401) {
        final refreshed = await AuthService.refreshToken();
        if (refreshed) {
          final retryResponse = await request().timeout(_timeoutDuration);
          return _handleResponse(retryResponse);
        }
      }
      return _handleResponse(response);
    } on SocketException {
      throw ApiException('No internet connection');
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Something went wrong. Please try again.');
    }
  }

  static Future<dynamic> get(String endpoint) async {
    return _safeRequest(() async {
      final headers = await _getHeaders();
      return http.get(Uri.parse('${AppConfig.baseUrl}$endpoint'), headers: headers);
    });
  }

  static Future<dynamic> post(String endpoint, [Map<String, dynamic>? body]) async {
    return _safeRequest(() async {
      final headers = await _getHeaders();
      return http.post(
        Uri.parse('${AppConfig.baseUrl}$endpoint'),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
    });
  }

  static Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    return _safeRequest(() async {
      final headers = await _getHeaders();
      return http.put(
        Uri.parse('${AppConfig.baseUrl}$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      );
    });
  }

  static Future<dynamic> patch(String endpoint, Map<String, dynamic> body) async {
    return _safeRequest(() async {
      final headers = await _getHeaders();
      return http.patch(
        Uri.parse('${AppConfig.baseUrl}$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      );
    });
  }

  static Future<dynamic> delete(String endpoint) async {
    return _safeRequest(() async {
      final headers = await _getHeaders();
      return http.delete(Uri.parse('${AppConfig.baseUrl}$endpoint'), headers: headers);
    });
  }

  // ── Presigned upload helpers ─────────────────────────────────────────

  /// Requests a short-lived presigned PUT URL from the backend for a
  /// direct client-to-R2 upload, bypassing the application server entirely.
  ///
  /// [type] must be `'photo'` or `'video'`. Returns a [PresignedUpload]
  /// containing the presigned upload URL, the permanent public URL, and
  /// the R2 object key.
  ///
  /// Throws [ApiException] if the request fails (auth, validation, or
  /// server error).
  static Future<PresignedUpload> requestPresignedUpload(
    String type, {
    String? contentHash,
  }) async {
    final body = <String, String>{'type': type};
    if (contentHash != null) body['contentHash'] = contentHash;
    final response = await post('/api/properties/presign-upload', body);
    return PresignedUpload.fromJson(response as Map<String, dynamic>);
  }

  /// Records a completed direct upload in the content-hash index so future
  /// identical files can be short-circuited at the presign step.
  ///
  /// Called after a successful PUT to R2. Fire-and-forget — failures are
  /// logged but do not block the user flow (dedup is a best-effort
  /// optimization, not a correctness requirement).
  static Future<void> confirmUpload({
    required String contentHash,
    required String publicUrl,
    required String key,
    required String contentType,
    required int sizeBytes,
  }) async {
    try {
      await post('/api/properties/confirm-upload', {
        'contentHash': contentHash,
        'publicUrl': publicUrl,
        'key': key,
        'contentType': contentType,
        'sizeBytes': sizeBytes.toString(),
      });
    } catch (e) {
      // Best-effort — dedup index miss just means a future re-upload,
      // which is harmless. Don't interrupt the user flow.
      debugPrint('confirm-upload failed (non-fatal): $e');
    }
  }

  static dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isNotEmpty) {
        return jsonDecode(response.body);
      }
      return null;
    } else if (response.statusCode == 401) {
      AuthService.logout();
      throw ApiException('Session expired. Please sign in again.');
    } else if (response.statusCode == 403) {
      String errorMessage = 'You do not have permission to perform this action.';
      try {
        final errorJson = jsonDecode(response.body);
        if (errorJson['error'] != null) {
          errorMessage = errorJson['error'];
        } else if (errorJson['message'] != null) {
          errorMessage = errorJson['message'];
        }
      } catch (e) {
        // Body wasn't JSON (or didn't have the expected shape) -- fall
        // back to the raw body if it has anything readable, otherwise
        // keep the generic message. Either way we still throw below, so
        // this never swallows the 403 itself, just how we phrase it.
        debugPrint('Failed to parse 403 error body: $e');
        if (response.body.isNotEmpty) {
          errorMessage = response.body;
        }
      }
      throw ApiException(errorMessage);
    } else {
      String errorMessage = 'Request failed with status: ${response.statusCode}';
      try {
        final errorJson = jsonDecode(response.body);
        if (errorJson['error'] != null) {
          errorMessage = errorJson['error'];
        } else if (errorJson['message'] != null) {
          errorMessage = errorJson['message'];
        }
      } catch (_) {
        if (response.body.isNotEmpty) {
          errorMessage = response.body;
        }
      }
      throw ApiException(errorMessage);
    }
  }
}
