import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/country_service.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/theme/app_text_styles.dart';
import 'package:roost_app/widgets/property/property_image.dart';

class LandlordPropertyCard extends StatelessWidget {
  final Property property;
  final bool isBusy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleAvailability;
  final VoidCallback onPublish;
  final VoidCallback onViewApplications;
  final VoidCallback onVerifyGps;
  final VoidCallback onShareEndorsement;
  final VoidCallback onViewEndorsementBadge;

  const LandlordPropertyCard({
    super.key,
    required this.property,
    required this.isBusy,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleAvailability,
    required this.onPublish,
    required this.onViewApplications,
    required this.onVerifyGps,
    required this.onShareEndorsement,
    required this.onViewEndorsementBadge,
  });

  @override
  Widget build(BuildContext context) {
    final isDraft = property.status == 'DRAFT';
    final isPublished = property.status == 'PUBLISHED';
    final formattedDate = property.listedAt != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(property.listedAt!))
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: property.available
              ? AppColors.border
              : AppColors.textSecondary.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: AppColors.shadowSm,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Thumbnail + Info
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 84,
                      height: 84,
                      child: PropertyImage(
                        imageUrls: [if (property.imageUrl != null) property.imageUrl!],
                        width: 84,
                        height: 84,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title, Location, Price, Status Pill
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                property.title,
                                style: AppTextStyles.title.copyWith(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _buildStatusBadge(isDraft),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              color: AppColors.textSecondary,
                              size: 13,
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                property.location,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              CountryService.price(property.price),
                              style: AppTextStyles.priceCompact.copyWith(
                                color: AppColors.accent,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            _buildAvailabilityChip(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: AppColors.border, height: 1),
              ),

              // Middle Row: Date / Primary Action Button
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    color: AppColors.textTertiary,
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isDraft
                        ? 'Not published yet'
                        : (formattedDate != null ? 'Listed $formattedDate' : 'Listed recently'),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  if (isDraft)
                    TextButton.icon(
                      onPressed: isBusy ? null : () {
                        HapticFeedback.lightImpact();
                        onPublish();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.amber,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: isBusy
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
                            )
                          : const Icon(Icons.publish_rounded, size: 14),
                      label: const Text(
                        'Publish',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        onViewApplications();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surfaceRaised,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: AppColors.border),
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.people_outline_rounded, size: 14),
                      label: const Text(
                        'Applications',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),

              // On-Site GPS Verification Pill (if published & unverified)
              if (isPublished && !property.gpsVerified) ...[
                const SizedBox(height: 10),
                InkWell(
                  onTap: isBusy ? null : () {
                    HapticFeedback.lightImpact();
                    onVerifyGps();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        if (isBusy)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
                          )
                        else
                          const Icon(Icons.my_location_rounded, color: Colors.amber, size: 15),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Stand at property & tap to verify GPS location',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Colors.amber, size: 16),
                      ],
                    ),
                  ),
                ),
              ],

              // Caretaker / Landlord Endorsement Pill (if applicable)
              if (!property.isDirectLandlord) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: property.landlordEndorsed
                        ? const Color(0xFF10B981).withValues(alpha: 0.08)
                        : Colors.amber.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: property.landlordEndorsed
                          ? const Color(0xFF10B981).withValues(alpha: 0.25)
                          : Colors.amber.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        property.landlordEndorsed
                            ? Icons.verified_user_rounded
                            : Icons.mark_email_unread_outlined,
                        color: property.landlordEndorsed
                            ? const Color(0xFF10B981)
                            : Colors.amber,
                        size: 15,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          property.landlordEndorsed
                              ? 'Landlord Endorsed Listing'
                              : 'Pending Owner Endorsement',
                          style: TextStyle(
                            color: property.landlordEndorsed
                                ? const Color(0xFF10B981)
                                : Colors.amber,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          if (property.landlordEndorsed) {
                            onViewEndorsementBadge();
                          } else {
                            onShareEndorsement();
                          }
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: property.landlordEndorsed
                                ? const Color(0xFF10B981)
                                : Colors.amber,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                property.landlordEndorsed
                                    ? Icons.check_circle_outline
                                    : Icons.share_rounded,
                                color: Colors.black,
                                size: 11,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                property.landlordEndorsed ? 'View Badge' : 'Send Link',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // Bottom Action Controls Row: Edit, Delete, Availability Switch
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 20),
                        tooltip: 'Edit listing',
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          onEdit();
                        },
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                        tooltip: 'Delete listing',
                        onPressed: isBusy ? null : () {
                          HapticFeedback.lightImpact();
                          onDelete();
                        },
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        property.available ? 'Available' : 'Rented',
                        style: TextStyle(
                          color: property.available ? AppColors.accent : AppColors.textTertiary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: property.available,
                          activeThumbColor: Colors.white,
                          activeTrackColor: AppColors.accent,
                          inactiveThumbColor: AppColors.grey500,
                          inactiveTrackColor: AppColors.surfaceRaised,
                          onChanged: isBusy ? null : (val) {
                            HapticFeedback.selectionClick();
                            onToggleAvailability(val);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isDraft) {
    if (isDraft) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.amber, width: 1),
        ),
        child: const Text(
          'DRAFT',
          style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      );
    }
    if (property.gpsVerified) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF10B981), width: 1),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 10),
            SizedBox(width: 3),
            Text(
              'VERIFIED',
              style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.3), width: 1),
      ),
      child: const Text(
        'LIVE',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildAvailabilityChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: property.available
            ? AppColors.accent.withValues(alpha: 0.12)
            : AppColors.textTertiary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        property.available ? 'AVAILABLE' : 'RENTED',
        style: TextStyle(
          color: property.available ? AppColors.accent : AppColors.textTertiary,
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
    );
  }
}
