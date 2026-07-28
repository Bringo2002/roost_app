import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:roost_app/config.dart';
import 'package:roost_app/services/push_notification_service.dart';

class AuthResult {
  final bool success;
  final String? error;
  AuthResult({required this.success, this.error});
}

class AuthService {
  static final String baseUrl = '${AppConfig.baseurl}/api/auth';
  static const String _tokenKey = 'jwt_token';

  static Future<AuthResult> signup(String name, String email, String password, String role) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'role': role,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveToken(data['token']);
        return AuthResult(success: true);
      }

      // Try to extract error message from response
      String errorMsg = 'Signup failed (${response.statusCode})';
      try {
        final body = jsonDecode(response.body);
        if (body['error'] != null) {
          errorMsg = body['error'];
        } else if (body['message'] != null) {
          errorMsg = body['message'];
        }
      } catch (_) {}
      return AuthResult(success: false, error: errorMsg);
    } on SocketException {
      return AuthResult(success: false, error: 'Cannot reach server. Check your internet connection.');
    } on http.ClientException {
      return AuthResult(success: false, error: 'Connection error. The server may be down.');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        return AuthResult(success: false, error: 'Request timed out. Please try again.');
      }
      return AuthResult(success: false, error: 'Unexpected error: $e');
    }
  }

  static Future<AuthResult> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveToken(data['token']);
        return AuthResult(success: true);
      }

      String errorMsg = 'Login failed (${response.statusCode})';
      try {
        final body = jsonDecode(response.body);
        if (body['error'] != null) {
          errorMsg = body['error'];
        } else if (body['message'] != null) {
          errorMsg = body['message'];
        }
      } catch (_) {}
      return AuthResult(success: false, error: errorMsg);
    } on SocketException {
      return AuthResult(success: false, error: 'Cannot reach server. Check your internet connection.');
    } on http.ClientException {
      return AuthResult(success: false, error: 'Connection error. The server may be down.');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        return AuthResult(success: false, error: 'Request timed out. Please try again.');
      }
      return AuthResult(success: false, error: 'Unexpected error: $e');
    }
  }

  /// Changes the current user's password via POST /api/auth/change-password.
  ///
  /// This used to probe three different endpoint paths with four payload
  /// key variants, plus fall back to PUT /api/users/me if all three
  /// 404'd -- leftover from before the backend's shape was settled. That
  /// fallback was also a real bug: PUT /api/users/me only reads name/phone
  /// from its payload and silently ignores an unrecognized `password` key,
  /// so it would return 200 (a harmless no-op profile save) and this
  /// method would report success even though the password was never
  /// actually changed. Now that /api/auth/change-password is a known,
  /// stable endpoint, there's exactly one call and no ambiguity.
  static Future<AuthResult> changePassword(String currentPassword, String newPassword) async {
    try {
      final token = await getToken();
      if (token == null) {
        return AuthResult(success: false, error: 'Not authenticated. Please log in again.');
      }

      final res = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/auth/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200 || res.statusCode == 204) {
        return AuthResult(success: true);
      }

      String errorMsg = 'Failed to change password (${res.statusCode})';
      try {
        final body = jsonDecode(res.body);
        if (body['error'] != null) errorMsg = body['error'];
      } catch (_) {}
      return AuthResult(success: false, error: errorMsg);
    } on SocketException {
      return AuthResult(success: false, error: 'No internet connection');
    } catch (e) {
      return AuthResult(success: false, error: 'An unexpected error occurred');
    }
  }

  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await PushNotificationService.reloadForUser();
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<String?> getUserEmail() async {
    final token = await getToken();
    if (token != null) {
      try {
        final Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
        return decodedToken['sub'];
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await PushNotificationService.reloadForUser();
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return false;
    try {
      if (JwtDecoder.isExpired(token)) {
        await logout();
        return false;
      }
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }
}
