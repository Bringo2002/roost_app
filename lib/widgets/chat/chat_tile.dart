import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:roost_app/models/conversation_summary.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/theme/app_text_styles.dart';
import 'package:roost_app/theme/app_theme.dart';

/// A single row in the active-chats list: initials avatar with a live
/// online indicator, name, role pill, last message preview, timestamp,
/// and unread count badge.
class ChatTile extends StatelessWidget {
  const ChatTile({super.key, required this.summary, required this.onTap});

  final ConversationSummary summary;
  final VoidCallback onTap;

  String _formatMessageTime(DateTime? time) {
    if (time == null) return '';
    final local = time.toLocal();
    final now = DateTime.now();
    final isToday = local.year == now.year && local.month == now.month && local.day == now.day;
    if (isToday) return DateFormat('h:mm a').format(local);
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = local.year == yesterday.year && local.month == yesterday.month && local.day == yesterday.day;
    if (isYesterday) return 'Yesterday';
    return DateFormat('MMM d').format(local);
  }

  @override
  Widget build(BuildContext context) {
    final partner = summary.partner;
    final online = partner.isOnline;
    final hasUnread = summary.unreadCount > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              _Avatar(name: partner.name, online: online),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            partner.name.isNotEmpty ? partner.name : 'Unknown',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.title,
                          ),
                        ),
                        if (summary.lastMessageTimestamp != null)
                          Text(
                            _formatMessageTime(summary.lastMessageTimestamp),
                            style: AppTextStyles.meta.copyWith(fontSize: 11),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _RolePill(role: partner.role),
                        if (partner.role.isNotEmpty) const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            summary.decryptedPreview ?? (summary.hasAttachment ? '📎 Attachment' : 'No messages yet'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.meta.copyWith(
                              fontSize: 13,
                              color: hasUnread ? AppColors.textPrimary : AppColors.textTertiary,
                              fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(minWidth: 20),
                            alignment: Alignment.center,
                            child: Text(
                              '${summary.unreadCount}',
                              style: AppTextStyles.chipLabel.copyWith(
                                color: AppColors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.online});

  final String name;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceRaised,
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: AppTextStyles.title.copyWith(fontSize: 18),
            ),
          ),
          if (online)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.onlineAccent,
                  border: Border.all(color: AppColors.background, width: 2.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    if (role.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        role.toUpperCase(),
        style: AppTextStyles.chipLabel.copyWith(
          color: AppColors.textTertiary,
          fontSize: 10,
        ),
      ),
    );
  }
}
