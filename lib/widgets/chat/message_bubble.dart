import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/theme/app_text_styles.dart';

/// A single chat message bubble. Consecutive messages from the same sender
/// are visually grouped -- only the last one in a group shows a timestamp
/// and a fully rounded tail corner -- to keep dense conversations readable.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.content,
    required this.timestamp,
    required this.isMe,
    this.isGroupEnd = true,
  });

  final String content;
  final DateTime timestamp;
  final bool isMe;

  /// Whether this is the last message in a run of consecutive messages
  /// from the same sender (controls timestamp visibility and tail radius).
  final bool isGroupEnd;

  @override
  Widget build(BuildContext context) {
    final tailRadius = isGroupEnd ? const Radius.circular(4) : const Radius.circular(20);

    return Padding(
      padding: EdgeInsets.only(bottom: isGroupEnd ? 12 : 3),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  color: isMe ? AppColors.white : AppColors.surfaceRaised,
                  border: isMe ? null : Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: isMe ? const Radius.circular(20) : tailRadius,
                    bottomRight: isMe ? tailRadius : const Radius.circular(20),
                  ),
                ),
                child: Text(
                  content,
                  style: AppTextStyles.body.copyWith(
                    color: isMe ? AppColors.black : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            if (isGroupEnd) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  DateFormat('h:mm a').format(timestamp.toLocal()),
                  style: AppTextStyles.meta.copyWith(fontSize: 11),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
