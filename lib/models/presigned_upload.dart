/// Result of a presigned upload request from the backend.
///
/// The backend generates a short-lived presigned PUT URL via
/// `POST /api/properties/presign-upload`. The client PUTs raw file bytes
/// directly to [uploadUrl] with a matching `Content-Type` header. After
/// the PUT succeeds, the file is immediately accessible at [publicUrl].
///
/// When [existing] is `true`, the file was already uploaded (content-hash
/// dedup hit). In this case [uploadUrl] and [key] are empty — the client
/// should skip the PUT and use [publicUrl] directly.
///
/// This model mirrors the backend's `R2StorageService.PresignedUpload`
/// record, keeping the contract explicit on both sides.
class PresignedUpload {
  const PresignedUpload({
    required this.existing,
    required this.uploadUrl,
    required this.publicUrl,
    required this.key,
  });

  /// `true` if the backend found a dedup cache hit for the content hash.
  /// When true, [uploadUrl] and [key] are empty — skip the PUT.
  final bool existing;

  /// Short-lived presigned URL. PUT raw bytes here with a matching
  /// `Content-Type` header (e.g. `image/jpeg` or `video/mp4`).
  /// Expires after 15 minutes (photos) or 60 minutes (videos).
  /// Empty string when [existing] is `true`.
  final String uploadUrl;

  /// Permanent public URL — accessible immediately after the PUT succeeds
  /// (or immediately when [existing] is `true`).
  /// This URL is stored in the property's `imageUrls` or `videoUrl` field.
  final String publicUrl;

  /// R2 object key, e.g. `properties/uuid.jpg`. Retained for the
  /// `/confirm-upload` call and potential future deletion.
  /// Empty string when [existing] is `true`.
  final String key;

  /// Parses the JSON response from `POST /api/properties/presign-upload`.
  factory PresignedUpload.fromJson(Map<String, dynamic> json) {
    return PresignedUpload(
      existing: json['existing'] as bool? ?? false,
      uploadUrl: json['uploadUrl'] as String? ?? '',
      publicUrl: json['publicUrl'] as String,
      key: json['key'] as String? ?? '',
    );
  }
}
