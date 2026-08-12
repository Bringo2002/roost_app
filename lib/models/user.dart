import 'package:roost_app/utils/server_time.dart';

class User {
  final int id;
  final String name;
  final String email;
  final String role;

  /// Contact number, shown in the chat contact-info sheet. Null for
  /// contexts that don't send it (e.g. a property listing's owner
  /// summary uses its own separate landlordPhone field instead).
  final String? phone;

  /// Last time this user made an authenticated request, refreshed
  /// automatically server-side. Used to derive online / last-seen status;
  /// null if the user has never made an authenticated request yet.
  final DateTime? lastActiveAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.lastActiveAt,
  });

  /// True if the user was active recently enough to be considered online.
  bool get isOnline {
    if (lastActiveAt == null) return false;
    return DateTime.now().difference(lastActiveAt!) < const Duration(seconds: 45);
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      phone: json['phone']?.toString(),
      lastActiveAt: parseServerDateTime(json['lastActiveAt']?.toString()),
    );
  }
}
