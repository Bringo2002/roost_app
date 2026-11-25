import 'package:roost_app/utils/server_time.dart';

/// Someone the signed-in user has blocked.
///
/// Mirrors the backend's `BlockedUserDto`: an id, a name that may be missing
/// on an old or anonymized account, an optional photo, and when the block was
/// made. It carries no email or phone.
class BlockedUser {
  final int id;
  final String? name;
  final String? avatarUrl;
  final DateTime blockedAt;

  const BlockedUser({
    required this.id,
    this.name,
    this.avatarUrl,
    required this.blockedAt,
  });

  /// Reads one entry of the `GET /api/users/me/blocked` response.
  ///
  /// `id` and `blockedAt` are always sent; a response without them is a
  /// contract break and throws rather than being defaulted.
  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      blockedAt: parseServerDateTime(json['blockedAt'] as String)!,
    );
  }

  /// The name to show, or a neutral label when the account has none.
  String get displayName {
    final trimmed = name?.trim() ?? '';
    return trimmed.isEmpty ? 'Roost user' : trimmed;
  }

  /// The upper-cased first letter of the name, for an avatar placeholder.
  String get initial {
    final trimmed = name?.trim() ?? '';
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }
}
