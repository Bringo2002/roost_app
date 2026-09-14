import 'package:flutter/material.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/theme/app_text_styles.dart';

/// Renders whichever of the property's ~26 boolean amenity flags are
/// true, plus any free-text custom amenities the landlord added.
///
/// The (icon, label) -> flag mapping lives entirely in this one widget
/// now, rather than being copy-pasted inline in the page body -- so
/// adding an amenity to the design is a one-line change here, not a
/// hunt through a 1,000+ line build method.
class AmenitiesSection extends StatelessWidget {
  const AmenitiesSection({super.key, required this.property});

  final Property property;

  static final List<_AmenityFlag> _flags = [
    _AmenityFlag(Icons.directions_car_outlined, 'Parking', (p) => p.parking),
    _AmenityFlag(Icons.wifi, 'WiFi', (p) => p.wifi),
    _AmenityFlag(Icons.water_drop_outlined, '24hr Water', (p) => p.water),
    _AmenityFlag(Icons.security_outlined, 'Security', (p) => p.security),
    _AmenityFlag(Icons.balcony_outlined, 'Balcony', (p) => p.balcony),
    _AmenityFlag(Icons.pets_outlined, 'Pet Friendly', (p) => p.petFriendly),
    _AmenityFlag(Icons.single_bed_outlined, 'Furnished', (p) => p.furnished),
    _AmenityFlag(Icons.ac_unit_outlined, 'Air Conditioning', (p) => p.ac),
    _AmenityFlag(Icons.thermostat_outlined, 'Heating', (p) => p.heating),
    _AmenityFlag(Icons.local_laundry_service_outlined, 'Laundry', (p) => p.laundry),
    _AmenityFlag(Icons.tv_outlined, 'DSTV / Cable', (p) => p.dstv),
    _AmenityFlag(Icons.fence_outlined, 'Perimeter Fence', (p) => p.fence),
    _AmenityFlag(Icons.phone_in_talk_outlined, 'Intercom', (p) => p.intercom),
    _AmenityFlag(Icons.elevator_outlined, 'Elevator', (p) => p.elevator),
    _AmenityFlag(Icons.badge_outlined, 'Caretaker', (p) => p.caretaker),
    _AmenityFlag(Icons.deck_outlined, 'Rooftop Terrace', (p) => p.rooftop),
    _AmenityFlag(Icons.yard_outlined, 'Garden / Lawn', (p) => p.garden),
    _AmenityFlag(Icons.inventory_2_outlined, 'Storage Unit', (p) => p.storage),
    _AmenityFlag(Icons.pool_outlined, 'Swimming Pool', (p) => p.pool),
    _AmenityFlag(Icons.fitness_center_outlined, 'Gym / Fitness', (p) => p.gym),
    _AmenityFlag(Icons.child_care_outlined, 'Play Area', (p) => p.playArea),
    _AmenityFlag(Icons.cleaning_services_outlined, 'Cleaning Service', (p) => p.cleaning),
    _AmenityFlag(Icons.delete_outline, 'Garbage Collection', (p) => p.garbage),
    _AmenityFlag(Icons.accessible_outlined, 'Wheelchair Access', (p) => p.wheelchair),
    _AmenityFlag(Icons.wb_sunny_outlined, 'Solar Power', (p) => p.solar),
    _AmenityFlag(Icons.power_outlined, 'Backup Generator', (p) => p.generator),
  ];

  @override
  Widget build(BuildContext context) {
    final active = _flags.where((f) => f.isActive(property)).toList();
    if (active.isEmpty && property.customAmenities.isEmpty) return const SizedBox.shrink();

    // Just the chip grid -- the section heading is owned by the page,
    // same as every other section (Location, Hosted by, etc.), so it's
    // not duplicated when a caller wants to place its own heading.
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final flag in active) _AmenityChip(icon: flag.icon, label: flag.label),
        for (final custom in property.customAmenities) _AmenityChip(icon: Icons.stars_outlined, label: custom),
      ],
    );
  }
}

class _AmenityChip extends StatelessWidget {
  const _AmenityChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 6, right: 14, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(color: AppColors.grey800, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.white, size: 14),
          ),
          const SizedBox(width: 8),
          Text(label, style: AppTextStyles.chipLabel.copyWith(fontSize: 12.5, letterSpacing: 0)),
        ],
      ),
    );
  }
}

/// Tiny value type pairing a flag's presentation with the getter that
/// reads it off a [Property] -- keeps the big `_flags` table above as a
/// single readable list instead of 26 near-identical `if` statements.
class _AmenityFlag {
  const _AmenityFlag(this.icon, this.label, this.isActive);

  final IconData icon;
  final String label;
  final bool Function(Property) isActive;
}
