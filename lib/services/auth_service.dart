import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:roost_app/config.dart';
import 'package:roost_app/services/push_notification_service.dart';

class AuthResult {
  final bool success;
  final String? error;
  /// True only when this call created a brand-new account (Google
  /// sign-in on a first-time user). Lets the caller route to onboarding
  /// instead of home, matching what plain signup already does.
  final bool isNewUser;
  AuthResult({required this.success, this.error, this.isNewUser = false});
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

  static bool _googleSignInReady = false;

  /// The "Web client" OAuth client ID from google-services.json
  /// (client_type: 3) -- NOT the Android client ID (client_type: 1).
  /// On Android, google_sign_in v7's authenticate() will only populate
  /// authentication.idToken if this is passed to initialize(); without
  /// it, the account picker still works (the user can select an
  /// account), but the returned idToken is silently null, which is
  /// exactly what was showing up as "Google sign-in did not return a
  /// token" -- there was never a token to return, since nothing told
  /// the plugin which audience to mint one for.
  static const String _googleServerClientId =
      '1085731102031-c9285g1rff9qcm67tcep7ie0146ple5u.apps.googleusercontent.com';

  /// GoogleSignIn.instance.initialize() must be called exactly once
  /// before any other GoogleSignIn method -- this guard makes repeated
  /// calls to signInWithGoogle() safe without re-initializing.
  static Future<void> _ensureGoogleSignInReady() async {
    if (_googleSignInReady) return;
    await GoogleSignIn.instance.initialize(serverClientId: _googleServerClientId);
    _googleSignInReady = true;
  }

  /// Signs in (or signs up) with Google. [role] is only used the first
  /// time a given Google account signs up -- pass the value the user
  /// picked on the signup screen's Tenant/Landlord chips. It's ignored
  /// for an existing account, same as the plain signup form's role only
  /// applying at account creation.
  ///
  /// Flow: Google identity -> Firebase credential -> Firebase ID token
  /// -> our backend's /api/auth/google, which verifies that token and
  /// returns our own JWT (same shape as /login and /signup).
  static Future<AuthResult> signInWithGoogle({String? role}) async {
    try {
      await _ensureGoogleSignInReady();

      final googleUser = await GoogleSignIn.instance.authenticate(scopeHint: ['email']);
      final googleIdToken = googleUser.authentication.idToken;
      if (googleIdToken == null) {
        return AuthResult(success: false, error: 'Google sign-in did not return a token. Please try again.');
      }

      final credential = fb_auth.GoogleAuthProvider.credential(idToken: googleIdToken);
      final userCredential = await fb_auth.FirebaseAuth.instance.signInWithCredential(credential);
      final firebaseIdToken = await userCredential.user?.getIdToken();
      if (firebaseIdToken == null) {
        return AuthResult(success: false, error: 'Could not complete Google sign-in. Please try again.');
      }

      return _exchangeGoogleToken(firebaseIdToken, role);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        // User closed the account picker -- not an error, nothing to show.
        return AuthResult(success: false);
      }
      // The user-facing message stays generic, but the real exception
      // (e.g. a DEVELOPER_ERROR code, which almost always means the
      // signing certificate's SHA-1 isn't registered for this OAuth
      // client) is worth seeing in the console -- this exact class of
      // failure is invisible otherwise, since GoogleSignInException's
      // description rarely says anything more specific than the code.
      developer.log('Google sign-in failed: ${e.code} ${e.description ?? ''}', name: 'AuthService');
      return AuthResult(success: false, error: 'Google sign-in failed. Please try again.');
    } catch (e) {
      developer.log('Google sign-in failed with unexpected error: $e', name: 'AuthService');
      return AuthResult(success: false, error: 'Google sign-in failed. Please try again.');
    }
  }

  static Future<AuthResult> _exchangeGoogleToken(String firebaseIdToken, String? role) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idToken': firebaseIdToken,
          if (role != null) 'role': role,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveToken(data['token']);
        return AuthResult(success: true, isNewUser: data['isNewUser'] == true);
      }

      String errorMsg = 'Google sign-in failed (${response.statusCode})';
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

    // Best-effort: only matters for users who signed in with Google, and
    // failure here shouldn't block logout from completing.
    try {
      await fb_auth.FirebaseAuth.instance.signOut();
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
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
