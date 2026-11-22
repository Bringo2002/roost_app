import 'package:flutter/material.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/utils/deletion_date.dart';

/// Shown at the top of the profile while the account is waiting out its
/// deletion grace period, with a way to cancel it.
class DeletionScheduledBanner extends StatelessWidget {
  const DeletionScheduledBanner({
    super.key,
    required this.scheduledAt,
    required this.onCancel,
    this.cancelling = false,
  });

  /// When the account will be permanently deleted.
  final DateTime scheduledAt;

  /// Called when the user taps "Cancel deletion".
  final VoidCallback onCancel;

  /// True while a cancellation request is in flight; disables the button.
  final bool cancelling;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey600),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.schedule_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Account deletion scheduled',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your account will be permanently deleted on ${formatDeletionDate(scheduledAt)}. '
            'You can cancel any time before then.',
            style: TextStyle(color: Colors.grey[400], fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              key: const Key('cancel-deletion-button'),
              onPressed: cancelling ? null : onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: AppColors.grey600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: cancelling
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Cancel deletion', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
