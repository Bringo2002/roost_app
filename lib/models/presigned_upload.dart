/// Result of a presigned upload request from the backend.
///
/// The backend generates a short-lived presigned PUT URL via
/// `POST /api/properties/presign-upload`. The client PUTs raw file bytes
/// directly to [uploadUrl] with a matching `Content-Type` header. After
/// the PUT succeeds, the file is immediately accessible at [publicUrl].
///
/// This model mirrors the backend's `R2StorageService.PresignedUpload`
/// record, keeping the contract explicit on both sides.
class PresignedUpload {
  const PresignedUpload({
    required this.uploadUrl,
    required this.publicUrl,
    required this.key,
  });

  /// Short-lived presigned URL. PUT raw bytes here with a matching
  /// `Content-Type` header (e.g. `image/jpeg` or `video/mp4`).
  /// Expires after 15 minutes (photos) or 60 minutes (videos).
  final String uploadUrl;

  /// Permanent public URL — accessible immediately after the PUT succeeds.
  /// This URL is stored in the property's `imageUrls` or `videoUrl` field.
  final String publicUrl;

  /// R2 object key, e.g. `properties/uuid.jpg`. Retained for potential
  /// future deletion or deduplication support.
  final String key;

  /// Parses the JSON response from `POST /api/properties/presign-upload`.
  factory PresignedUpload.fromJson(Map<String, dynamic> json) {
    return PresignedUpload(
      uploadUrl: json['uploadUrl'] as String,
      publicUrl: json['publicUrl'] as String,
      key: json['key'] as String,
    );
  }
}
