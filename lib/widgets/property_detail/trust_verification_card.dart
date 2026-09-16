import 'package:flutter/material.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/widgets/property_detail/roost_bottom_sheet.dart';
import 'package:roost_app/pages/profile/public_host_profile_page.dart';

/// The "Hosted by" card: avatar, name, management-role badge (Direct
/// Owner / Caretaker Managed / Authorized Agent, with an "Endorsed"
/// variant), and a 3-item verification checkpoints grid (phone / GPS /
/// document proof).
///
/// Monochrome redesign of the previous version, which used a green glow
/// + border for verified listings and a purple tint for caretaker/agent
/// roles -- both accent colors, against the app's own declared
/// black/white/grey brand rule. Verified status is now expressed the
/// same way [VerificationBadges] does it: solid white fill vs. a
/// subdued outline, not a color swap.
class TrustVerificationCard extends StatelessWidget {
  const TrustVerificationCard({super.key, required this.property});

  final Property property;

  String get _name => property.landlordName ?? (property.owner?.name ?? 'Landlord');

  @override
  Widget build(BuildContext context) {
    final firstLetter = _name.isNotEmpty ? _name[0].toUpperCase() : 'L';
    final gpsOk = property.gpsVerified || property.verified;
    final docOk = property.documentVerified || property.documentUrls.isNotEmpty || property.verified;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: property.verified ? AppColors.white : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PublicHostProfilePage(
                    hostId: property.landlordId?.toString() ?? property.id?.toString() ?? 'host_123',
                    hostName: _name,
                    hostPhone: property.landlordPhone,
                    hostRole: 'LANDLORD',
                    isTitleDeedVerified: property.documentVerified || property.verified,
                    isPhoneVerified: true,
                    isOwnerEndorsed: property.landlordEndorsed,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.grey700, width: 1.5),
                    ),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.white,
                      child: Text(firstLetter, style: const TextStyle(color: AppColors.black, fontWeight: FontWeight.bold, fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            if (property.verified) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified, color: AppColors.white, size: 16),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        _ManagementRoleBadge(property: property),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.bolt, color: AppColors.grey500, size: 14),
                            const SizedBox(width: 4),
                            Text('Usually responds within 2 hours', style: TextStyle(color: AppColors.grey500, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.grey400, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 14),

          Text('Landlord Verification Proof', style: TextStyle(color: AppColors.grey400, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _TrustCheckpointPill(icon: Icons.phone_android_rounded, title: 'Phone SMS', isVerified: true, onTap: () => showDetails(context, property))),
              const SizedBox(width: 8),
              Expanded(child: _TrustCheckpointPill(icon: Icons.my_location_rounded, title: 'GPS Location', isVerified: gpsOk, onTap: () => showDetails(context, property))),
              const SizedBox(width: 8),
              Expanded(child: _TrustCheckpointPill(icon: Icons.description_outlined, title: 'Doc Proof', isVerified: docOk, onTap: () => showDetails(context, property))),
            ],
          ),

          if (property.verified) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(10)),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_rounded, color: AppColors.black, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '100% Verified Listing & Landlord — identity, location & document proofs confirmed.',
                      style: TextStyle(color: AppColors.black, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Shows the full breakdown behind the checkpoints grid above. Static
  /// so it can be triggered from the verification badges row too,
  /// without those badges needing to hold a reference to this widget.
  static void showDetails(BuildContext context, Property property) {
    final gpsOk = property.gpsVerified || property.verified;
    final docOk = property.documentVerified || property.documentUrls.isNotEmpty || property.verified;

    RoostBottomSheet.show(
      context: context,
      title: 'Roost Trust & Verification Proof',
      subtitle: 'Roost protects tenants by verifying landlord identity, location, and property authorization.',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProofModalRow(
            icon: Icons.phone_android_rounded,
            title: 'Phone Authenticated',
            subtitle: 'Landlord phone number verified via SMS OTP.',
            isVerified: true,
          ),
          const SizedBox(height: 14),
          _ProofModalRow(
            icon: Icons.my_location_rounded,
            title: 'On-Site GPS Location',
            subtitle: 'Landlord captured live coordinates physically at the property.',
            isVerified: gpsOk,
          ),
          const SizedBox(height: 14),
          _ProofModalRow(
            icon: Icons.description_outlined,
            title: 'Ownership / Utility Proof',
            subtitle: 'Title deed, utility bill or ID photo uploaded for review.',
            isVerified: docOk,
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.white,
                foregroundColor: AppColors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Got It', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagementRoleBadge extends StatelessWidget {
  const _ManagementRoleBadge({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    // Endorsed roles (landlord-vouched-for caretaker/agent) stand out
    // with a solid fill; every other role gets the subdued outline --
    // same solid-vs-outline hierarchy used throughout, no accent hue.
    final endorsed = !property.isDirectLandlord && property.landlordEndorsed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: endorsed ? AppColors.white : AppColors.grey800,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        property.managementBadgeLabel,
        style: TextStyle(
          color: endorsed ? AppColors.black : AppColors.grey400,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TrustCheckpointPill extends StatelessWidget {
  const _TrustCheckpointPill({required this.icon, required this.title, required this.isVerified, required this.onTap});

  final IconData icon;
  final String title;
  final bool isVerified;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isVerified ? AppColors.grey800 : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isVerified ? AppColors.grey600 : AppColors.divider),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isVerified ? Icons.check_circle_rounded : Icons.pending_outlined,
              color: isVerified ? AppColors.white : AppColors.grey500,
              size: 13,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  color: isVerified ? AppColors.white : AppColors.grey400,
                  fontSize: 11,
                  fontWeight: isVerified ? FontWeight.bold : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProofModalRow extends StatelessWidget {
  const _ProofModalRow({required this.icon, required this.title, required this.subtitle, required this.isVerified});

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isVerified ? AppColors.grey800 : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: isVerified ? AppColors.white : AppColors.grey500, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  Icon(
                    isVerified ? Icons.check_circle_rounded : Icons.pending_outlined,
                    color: isVerified ? AppColors.white : AppColors.grey500,
                    size: 14,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: AppColors.grey400, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}
