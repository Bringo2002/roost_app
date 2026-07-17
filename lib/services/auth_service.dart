import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:roost_app/config.dart';

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

  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
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
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
