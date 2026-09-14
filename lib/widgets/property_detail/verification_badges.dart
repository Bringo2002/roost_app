import 'package:flutter/material.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/theme/app_text_styles.dart';

/// The Available/Taken · Verified · GPS Confirmed · Doc Attached ·
/// Community Verified pill row shown under a listing's title.
///
/// Every badge here is strictly monochrome (white/grey), matching the
/// app's own declared brand rule -- the previous implementation used
/// `greenAccent` for "Verified"/"Community Verified", which broke that
/// rule. A verified pill is now distinguished from an unverified one by
/// weight and fill, not color: solid white fill instead of a translucent
/// grey outline.
class VerificationBadges extends StatelessWidget {
  const VerificationBadges({super.key, required this.property, this.onTapVerification});

  final Property property;

  /// Called when any verification-related badge is tapped, to open the
  /// full trust/verification details sheet. Null (no-op) if there's
  /// nothing more to show.
  final VoidCallback? onTapVerification;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _AvailabilityPill(available: property.available),
        if (property.verified)
          _Badge(icon: Icons.verified, label: 'Verified Listing', solid: true, onTap: onTapVerification),
        if (property.gpsVerified && !property.verified)
          _Badge(icon: Icons.my_location, label: 'GPS Confirmed', onTap: onTapVerification),
        if ((property.documentVerified || property.documentUrls.isNotEmpty) && !property.verified)
          _Badge(icon: Icons.description_outlined, label: 'Doc Attached', onTap: onTapVerification),
        if (property.communityVerified)
          const _Badge(icon: Icons.groups_2_outlined, label: 'Community Verified'),
      ],
    );
  }
}

class _AvailabilityPill extends StatelessWidget {
  const _AvailabilityPill({required this.available});

  final bool available;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: available ? AppColors.white : AppColors.grey900,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: available ? AppColors.black : AppColors.grey500,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            available ? 'Available' : 'Taken',
            style: TextStyle(
              color: available ? AppColors.black : AppColors.grey400,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Every verification badge shares one visual family. `solid: true`
/// (used for the primary "Verified Listing" badge) gets a filled-white
/// treatment; the rest get the subdued glass/outline look -- so the
/// strongest claim reads as visually strongest without reaching for color.
class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, this.solid = false, this.onTap});

  final IconData icon;
  final String label;
  final bool solid;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: solid ? AppColors.white : AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(999),
        border: solid ? null : Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: solid ? AppColors.black : AppColors.white, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: solid ? AppTextStyles.badge.copyWith(color: AppColors.black) : AppTextStyles.badge,
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(borderRadius: BorderRadius.circular(999), onTap: onTap, child: content);
  }
}
