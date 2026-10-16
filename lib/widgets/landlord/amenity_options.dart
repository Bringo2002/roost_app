import 'package:flutter/material.dart';
import 'package:roost_app/theme/amenity_colors.dart';
import 'package:roost_app/theme/app_colors.dart';

/// One selectable amenity in the add-property flow: the key the listing
/// payload uses, the label shown to the landlord, and its icon and color.
class AmenityOption {
  const AmenityOption({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String key;
  final String label;
  final IconData icon;
  final Color color;
}

/// Every standard amenity a landlord can toggle, in display order.
const kAmenityOptions = <AmenityOption>[
  // Comfort & Essentials
  AmenityOption(
      key: 'furnished',
      label: 'Furnished',
      icon: Icons.chair_outlined,
      color: AppColors.indigo),
  AmenityOption(
      key: 'wifi',
      label: 'WiFi / Fiber',
      icon: Icons.wifi,
      color: AppColors.landlordAccent),
  AmenityOption(
      key: 'water',
      label: '24hr Water / Borehole',
      icon: Icons.water_drop_outlined,
      color: AmenityColors.water),
  AmenityOption(
      key: 'generator',
      label: 'Backup Generator',
      icon: Icons.power_outlined,
      color: AmenityColors.generator),
  AmenityOption(
      key: 'solar',
      label: 'Solar Water Heater',
      icon: Icons.wb_sunny_outlined,
      color: AmenityColors.solar),
  AmenityOption(
      key: 'ac',
      label: 'Air Conditioning',
      icon: Icons.ac_unit,
      color: AmenityColors.ac),
  AmenityOption(
      key: 'heating',
      label: 'Heating',
      icon: Icons.local_fire_department_outlined,
      color: AmenityColors.heating),
  AmenityOption(
      key: 'laundry',
      label: 'In-Unit Laundry',
      icon: Icons.local_laundry_service_outlined,
      color: AmenityColors.laundry),
  AmenityOption(
      key: 'dstv',
      label: 'DSTV / Cable TV',
      icon: Icons.tv_outlined,
      color: AmenityColors.dstv),

  // Security & Building
  AmenityOption(
      key: 'security',
      label: 'CCTV & Security',
      icon: Icons.security,
      color: AmenityColors.security),
  AmenityOption(
      key: 'fence',
      label: 'Electric Fence',
      icon: Icons.fence,
      color: AmenityColors.fence),
  AmenityOption(
      key: 'intercom',
      label: 'Intercom Access',
      icon: Icons.doorbell_outlined,
      color: AmenityColors.intercom),
  AmenityOption(
      key: 'elevator',
      label: 'Elevator / Lift',
      icon: Icons.elevator_outlined,
      color: AmenityColors.elevator),
  AmenityOption(
      key: 'parking',
      label: 'Dedicated Parking',
      icon: Icons.local_parking_outlined,
      color: AmenityColors.parking),
  AmenityOption(
      key: 'caretaker',
      label: 'On-site Caretaker',
      icon: Icons.person_pin_outlined,
      color: AmenityColors.caretaker),

  // Space & Comfort
  AmenityOption(
      key: 'balcony',
      label: 'Private Balcony',
      icon: Icons.deck_outlined,
      color: AmenityColors.balcony),
  AmenityOption(
      key: 'rooftop',
      label: 'Rooftop Terrace',
      icon: Icons.apartment_outlined,
      color: AmenityColors.rooftop),
  AmenityOption(
      key: 'garden',
      label: 'Garden / Lawn',
      icon: Icons.grass_outlined,
      color: AmenityColors.garden),
  AmenityOption(
      key: 'storage',
      label: 'Storage Unit',
      icon: Icons.inventory_2_outlined,
      color: AmenityColors.storage),

  // Leisure & Services
  AmenityOption(
      key: 'pool',
      label: 'Swimming Pool',
      icon: Icons.pool,
      color: AmenityColors.pool),
  AmenityOption(
      key: 'gym',
      label: 'Gym & Fitness',
      icon: Icons.fitness_center,
      color: AmenityColors.gym),
  AmenityOption(
      key: 'playArea',
      label: 'Kids Play Area',
      icon: Icons.child_care_outlined,
      color: AmenityColors.playArea),
  AmenityOption(
      key: 'petFriendly',
      label: 'Pet Friendly',
      icon: Icons.pets,
      color: AmenityColors.petFriendly),
  AmenityOption(
      key: 'cleaning',
      label: 'Housekeeping',
      icon: Icons.cleaning_services_outlined,
      color: AmenityColors.cleaning),
  AmenityOption(
      key: 'garbage',
      label: 'Garbage Collection',
      icon: Icons.delete_outline,
      color: AmenityColors.garbage),
  AmenityOption(
      key: 'wheelchair',
      label: 'Wheelchair Access',
      icon: Icons.accessible,
      color: AmenityColors.wheelchair),
];
