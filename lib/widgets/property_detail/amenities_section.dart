import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/theme/amenity_colors.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/theme/app_text_styles.dart';

class AmenitiesSection extends StatefulWidget {
  const AmenitiesSection({super.key, required this.property});

  final Property property;

  static final List<_AmenityFlag> _flags = [
    _AmenityFlag(Icons.directions_car_outlined, 'Parking', (p) => p.parking, AmenityColors.parking),
    _AmenityFlag(Icons.wifi, 'WiFi', (p) => p.wifi, AppColors.landlordAccent),
    _AmenityFlag(Icons.water_drop_outlined, '24hr Water', (p) => p.water, AmenityColors.water),
    _AmenityFlag(Icons.security_outlined, 'Security', (p) => p.security, AmenityColors.security),
    _AmenityFlag(Icons.balcony_outlined, 'Balcony', (p) => p.balcony, AmenityColors.balcony),
    _AmenityFlag(Icons.pets_outlined, 'Pet Friendly', (p) => p.petFriendly, AmenityColors.petFriendly),
    _AmenityFlag(Icons.single_bed_outlined, 'Furnished', (p) => p.furnished, AppColors.indigo),
    _AmenityFlag(Icons.ac_unit_outlined, 'Air Conditioning', (p) => p.ac, AmenityColors.ac),
    _AmenityFlag(Icons.thermostat_outlined, 'Heating', (p) => p.heating, AmenityColors.heating),
    _AmenityFlag(Icons.local_laundry_service_outlined, 'Laundry', (p) => p.laundry, AmenityColors.laundry),
    _AmenityFlag(Icons.tv_outlined, 'DSTV / Cable', (p) => p.dstv, AmenityColors.dstv),
    _AmenityFlag(Icons.fence_outlined, 'Perimeter Fence', (p) => p.fence, AmenityColors.fence),
    _AmenityFlag(Icons.phone_in_talk_outlined, 'Intercom', (p) => p.intercom, AmenityColors.intercom),
    _AmenityFlag(Icons.elevator_outlined, 'Elevator', (p) => p.elevator, AmenityColors.elevator),
    _AmenityFlag(Icons.badge_outlined, 'Caretaker', (p) => p.caretaker, AmenityColors.caretaker),
    _AmenityFlag(Icons.deck_outlined, 'Rooftop Terrace', (p) => p.rooftop, AmenityColors.rooftop),
    _AmenityFlag(Icons.yard_outlined, 'Garden / Lawn', (p) => p.garden, AmenityColors.garden),
    _AmenityFlag(Icons.inventory_2_outlined, 'Storage Unit', (p) => p.storage, AmenityColors.storage),
    _AmenityFlag(Icons.pool_outlined, 'Swimming Pool', (p) => p.pool, AmenityColors.pool),
    _AmenityFlag(Icons.fitness_center_outlined, 'Gym / Fitness', (p) => p.gym, AmenityColors.gym),
    _AmenityFlag(Icons.child_care_outlined, 'Play Area', (p) => p.playArea, AmenityColors.playArea),
    _AmenityFlag(Icons.cleaning_services_outlined, 'Cleaning Service', (p) => p.cleaning, AmenityColors.cleaning),
    _AmenityFlag(Icons.delete_outline, 'Garbage Collection', (p) => p.garbage, AmenityColors.garbage),
    _AmenityFlag(Icons.accessible_outlined, 'Wheelchair Access', (p) => p.wheelchair, AmenityColors.wheelchair),
    _AmenityFlag(Icons.wb_sunny_outlined, 'Solar Power', (p) => p.solar, AmenityColors.solar),
    _AmenityFlag(Icons.power_outlined, 'Backup Generator', (p) => p.generator, AmenityColors.generator),
  ];

  @override
  State<AmenitiesSection> createState() => _AmenitiesSectionState();
}

class _AmenitiesSectionState extends State<AmenitiesSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final active = AmenitiesSection._flags.where((f) => f.isActive(widget.property)).toList();
    final allAmenities = [
      ...active.map((f) => _AmenityChip(icon: f.icon, label: f.label, color: f.color)),
      ...widget.property.customAmenities.map((c) => _AmenityChip(icon: Icons.stars_outlined, label: c, color: AppColors.gold)),
    ];

    if (allAmenities.isEmpty) return const SizedBox.shrink();

    final showToggle = allAmenities.length > 6;
    final displayedAmenities = _expanded || !showToggle ? allAmenities : allAmenities.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 44,
            ),
            itemCount: displayedAmenities.length,
            itemBuilder: (context, idx) => displayedAmenities[idx],
          ),
        ),
        if (showToggle) ...[
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _expanded = !_expanded);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.white,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              _expanded ? 'Show less' : 'Show all ${allAmenities.length} amenities',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }
}

class _AmenityChip extends StatelessWidget {
  const _AmenityChip({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 6, right: 10, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.chipLabel.copyWith(fontSize: 12, letterSpacing: 0),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _AmenityFlag {
  const _AmenityFlag(this.icon, this.label, this.isActive, this.color);

  final IconData icon;
  final String label;
  final bool Function(Property) isActive;
  final Color color;
}
