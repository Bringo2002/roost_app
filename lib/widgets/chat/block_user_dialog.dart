import 'package:flutter/material.dart';
import 'package:roost_app/theme/app_colors.dart';

/// Asks the person to confirm blocking [userName]. Completes with true only
/// when they choose Block; cancelling or dismissing the dialog is false.
///
/// Shared by the chat room and the host profile so both say the same thing
/// about what blocking does.
Future<bool> confirmBlockUser(BuildContext context, String userName) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Block $userName?', style: const TextStyle(color: Colors.white, fontSize: 18)),
      content: const Text(
        'They won\'t be able to message you, and you won\'t see their messages. '
        'You can unblock them any time from Profile > Blocked users.',
        style: TextStyle(color: Colors.grey, fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Block', style: TextStyle(color: AppColors.destructive, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
  return confirmed == true;
}
