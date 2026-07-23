import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:roost_app/config.dart';

/// Helper service for uploading photos and files directly to Cloudinary or backend.
class CloudinaryService {
  CloudinaryService._();

  // Cloudinary upload preset and cloud name (default public demo or custom roost config)
  static const String _cloudName = 'roost-app';
  static const String _uploadPreset = 'roost_unsigned';

  /// Uploads binary file bytes to Cloudinary unsigned preset and returns the secure URL.
  /// Falls back to backend upload endpoint if Cloudinary is unreachable or fails.
  static Future<String?> uploadImage(Uint8List bytes, {String fileName = 'upload.jpg'}) async {
    try {
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));

      final response = await request.send().timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 || response.statusCode == 201) {
        final resBody = await response.stream.bytesToString();
        final data = jsonDecode(resBody);
        return data['secure_url'] as String?;
      }
    } catch (_) {
      // Cloudinary fallback: if unsigned preset is unavailable, post to backend api
    }

    // Backend endpoint fallback
    try {
      final backendUri = Uri.parse('${AppConfig.baseUrl}/api/upload');
      final req = http.MultipartRequest('POST', backendUri)
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));

      final res = await req.send().timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final body = await res.stream.bytesToString();
        final data = jsonDecode(body);
        return data['url'] as String?;
      }
    } catch (_) {}

    return null;
  }
}
