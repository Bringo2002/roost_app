import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/cloudinary_service.dart';

/// Thrown by [AvatarUploadHelper.pickUploadAndSave] specifically when
/// the CDN upload succeeded but persisting the URL to the user's
/// profile failed. Carries [uploadedUrl] so a caller can retry just the
/// save step -- via [AvatarUploadHelper.saveToProfile] directly --
/// instead of re-uploading the same photo and leaving yet another
/// orphaned file on the CDN with no reference anywhere.
class AvatarSaveException implements Exception {
  AvatarSaveException(this.uploadedUrl, this.message);

  final String uploadedUrl;
  final String message;

  @override
  String toString() => message;
}

/// Coordinates the full avatar upload flow:
/// pick → compress → upload to CDN → persist URL to backend.
class AvatarUploadHelper {
  AvatarUploadHelper._();

  static final ImagePicker _picker = ImagePicker();

  /// Prompts the user to pick an image from [source] (camera or gallery).
  ///
  /// Capped at 2048x2048 -- generous enough for the full-screen avatar
  /// viewer, since avatars are now viewable that way.
  /// Returns the image bytes, or `null` if the user cancelled.
  static Future<Uint8List?> pickAndCompress(ImageSource source) async {
    final XFile? file = await _picker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 98,
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
  /// Throws [Exception] if the upload itself fails, or
  /// [AvatarSaveException] (carrying the already-uploaded URL) if the
  /// upload succeeded but saving it to the profile failed -- see that
  /// class's doc comment for why the distinction matters.
  static Future<String?> pickUploadAndSave(ImageSource source) async {
    final bytes = await pickAndCompress(source);
    if (bytes == null) return null;

    final url = await uploadBytes(bytes);
    if (url == null) throw Exception('Image upload failed. Please try again.');

    try {
      await saveToProfile(url);
    } catch (_) {
      throw AvatarSaveException(url, 'Photo uploaded but could not be saved to your profile. Please try again.');
    }
    return url;
  }
}
