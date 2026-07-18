import 'package:flutter/material.dart';
import 'package:roost_app/models/user.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/theme/app_text_styles.dart';
import 'package:roost_app/theme/app_theme.dart';
import 'package:roost_app/utils/presence_formatter.dart';

/// A single row in the active-chats list: initials avatar with a live
/// online indicator, name, role pill + presence, and a chevron.
class ChatTile extends StatelessWidget {
  const ChatTile({super.key, required this.partner, required this.onTap});

  final User partner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final online = partner.isOnline;

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
                    Text(
                      partner.name.isNotEmpty ? partner.name : 'Unknown',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.title,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _RolePill(role: partner.role),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            online ? 'Online' : formatLastSeen(partner.lastActiveAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.meta.copyWith(
                              fontSize: 11,
                              color: online ? AppColors.onlineAccent : AppColors.textTertiary,
                              fontWeight: online ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: AppColors.grey600,
                size: 20,
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
