import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/theme/app_colors.dart';

/// Shown only when a property is managed by a caretaker or agent rather
/// than the landlord directly -- surfaces both contacts (caretaker/agent
/// AND owner) side by side so a renter always knows who they're actually
/// dealing with. Previously used a purple accent for the caretaker/agent
/// row and teal for the landlord row; both rows now share the same
/// monochrome treatment, since the app's brand rule is black/white/grey
/// only -- the two roles are already distinguished by their label text
/// and icon, they don't need different colors as well.
class DualContactCard extends StatelessWidget {
  const DualContactCard({super.key, required this.property});

  final Property property;

  bool get _shouldShow => !property.isDirectLandlord && (property.caretakerName?.isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow) return const SizedBox.shrink();

    final landlordName = property.landlordName ?? (property.owner?.name ?? 'Landlord');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Property Contacts', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text('Both contacts are shown for your trust and convenience', style: TextStyle(color: AppColors.grey500, fontSize: 11)),
          const SizedBox(height: 16),
          _ContactRow(
            roleLabel: property.isCaretaker ? 'On-site Caretaker' : 'Authorized Agent',
            name: property.caretakerName!,
            phone: property.caretakerPhone ?? '',
            icon: property.isCaretaker ? Icons.person_pin : Icons.support_agent,
            livesOnSite: property.isCaretaker && property.caretakerLivesOnSite,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: AppColors.divider),
          ),
          _ContactRow(
            roleLabel: 'Property Owner',
            name: landlordName,
            phone: property.landlordPhone,
            icon: Icons.home_outlined,
            endorsed: property.landlordEndorsed,
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.roleLabel,
    required this.name,
    required this.phone,
    required this.icon,
    this.livesOnSite = false,
    this.endorsed = false,
  });

  final String roleLabel;
  final String name;
  final String phone;
  final IconData icon;
  final bool livesOnSite;
  final bool endorsed;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: AppColors.grey800, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: AppColors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (endorsed) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(4)),
                      child: const Text('Endorsed', style: TextStyle(color: AppColors.black, fontSize: 9, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Text(roleLabel, style: TextStyle(color: AppColors.grey500, fontSize: 11)),
                  if (livesOnSite) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.location_on, color: AppColors.grey600, size: 11),
                    const SizedBox(width: 2),
                    Text('Lives on-site', style: TextStyle(color: AppColors.grey500, fontSize: 10)),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (phone.isNotEmpty) ...[
          _ContactIconButton(icon: Icons.phone_outlined, onTap: () => launchUrl(Uri.parse('tel:$phone')), tooltip: 'Call $name'),
          const SizedBox(width: 6),
          _ContactIconButton(
            icon: Icons.chat_bubble_outline,
            onTap: () => launchUrl(Uri.parse('https://wa.me/${phone.replaceAll('+', '')}')),
            tooltip: 'WhatsApp $name',
          ),
        ],
      ],
    );
  }
}

class _ContactIconButton extends StatelessWidget {
  const _ContactIconButton({required this.icon, required this.onTap, required this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, color: AppColors.white, size: 16),
        ),
      ),
    );
  }
}
