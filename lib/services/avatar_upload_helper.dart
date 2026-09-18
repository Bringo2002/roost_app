import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/cloudinary_service.dart';

/// Coordinates the full avatar upload flow:
/// pick → compress → upload to CDN → persist URL to backend.
class AvatarUploadHelper {
  AvatarUploadHelper._();

  static final ImagePicker _picker = ImagePicker();

  /// Prompts the user to pick an image from [source] (camera or gallery).
  ///
  /// Images are resized to a maximum of 500 × 500 px and compressed to
  /// 80 % JPEG quality on-device before any bytes leave the device.
  /// Returns the compressed bytes, or `null` if the user cancelled.
  static Future<Uint8List?> pickAndCompress(ImageSource source) async {
    final XFile? file = await _picker.pickImage(
      source: source,
      maxWidth: 500,
      maxHeight: 500,
      imageQuality: 80,
    );
    if (file == null) return null;
    return file.readAsBytes();
  }

  /// Uploads [bytes] to cloud storage and returns the public CDN URL.
  ///
  /// Delegates to [CloudinaryService.uploadImage] which already handles a
  /// backend fallback endpoint if Cloudinary is unreachable.
  /// Returns `null` on total failure.
  static Future<String?> uploadBytes(Uint8List bytes) {
    final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    return CloudinaryService.uploadImage(bytes, fileName: fileName);
  }

  /// Persists [avatarUrl] to the authenticated user's profile via
  /// `PATCH /api/users/me`.
  ///
  /// Throws [ApiException] on network or server errors — callers are
  /// expected to surface these to the user.
  static Future<void> saveToProfile(String avatarUrl) {
    return ApiService.patch('/api/users/me', {'avatarUrl': avatarUrl});
  }

  /// Removes the user's current profile picture by clearing avatarUrl.
  static Future<void> removeAvatar() {
    return saveToProfile('');
  }

  /// Convenience method that runs the complete flow in one call:
  /// pick → compress → upload → persist.
  ///
  /// Returns the CDN URL on success, `null` if the user cancelled the picker.
  /// Throws [ApiException] or [Exception] on upload / network failures.
  static Future<String?> pickUploadAndSave(ImageSource source) async {
    final bytes = await pickAndCompress(source);
    if (bytes == null) return null;

    final url = await uploadBytes(bytes);
    if (url == null) throw Exception('Image upload failed. Please try again.');

    await saveToProfile(url);
    return url;
  }
}
