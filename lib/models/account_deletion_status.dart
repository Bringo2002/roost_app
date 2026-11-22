import 'package:roost_app/utils/server_time.dart';

/// Where an account stands in the two-phase deletion flow.
///
/// Mirrors the backend's `AccountDeletionStatusDto`. [status] is
/// `scheduled` while the grace period is running, `cancelled` straight after
/// a cancellation, and `none` when nothing is pending.
class AccountDeletionStatus {
  final String status;
  final DateTime? requestedAt;
  final DateTime? scheduledAt;
  final int gracePeriodDays;

  const AccountDeletionStatus({
    required this.status,
    this.requestedAt,
    this.scheduledAt,
    this.gracePeriodDays = 0,
  });

  /// True while the account is waiting out its grace period.
  bool get isScheduled => status == 'scheduled';

  factory AccountDeletionStatus.fromJson(Map<String, dynamic> json) {
    return AccountDeletionStatus(
      status: json['status']?.toString() ?? 'none',
      requestedAt: parseServerDateTime(json['deletionRequestedAt']?.toString()),
      scheduledAt: parseServerDateTime(json['deletionScheduledAt']?.toString()),
      gracePeriodDays: (json['gracePeriodDays'] as num?)?.toInt() ?? 0,
    );
  }
}
