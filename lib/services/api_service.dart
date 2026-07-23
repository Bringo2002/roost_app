import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:roost_app/config.dart';
import 'package:roost_app/services/auth_service.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
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

  static Future<dynamic> delete(String endpoint) async {
    return _safeRequest(() async {
      final headers = await _getHeaders();
      return http.delete(Uri.parse('${AppConfig.baseUrl}$endpoint'), headers: headers);
    });
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
