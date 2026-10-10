import 'package:flutter/material.dart';
import 'package:roost_app/l10n/generated/app_localizations.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/utils/maps_navigation.dart';

/// One nearby place (mall / hospital / major road) as a tappable pill:
/// category icon + "600m from TRM Mall". Tapping opens Google Maps
/// directions to it. Localized, screen-reader friendly, and safe for long
/// names (wraps to two lines, then ellipsizes).
class NearbyFacilityChip extends StatelessWidget {
  final NearbyFacility facility;

  const NearbyFacilityChip({super.key, required this.facility});

  static IconData _icon(String category) {
    switch (category) {
      case 'mall':
        return Icons.shopping_bag_outlined;
      case 'hospital':
        return Icons.local_hospital_outlined;
      case 'road':
        return Icons.add_road_outlined;
      default:
        return Icons.place_outlined;
    }
  }

  static String _categoryLabel(AppLocalizations l10n, String category) {
    switch (category) {
      case 'mall':
        return l10n.nearbyFacilityCategoryMall;
      case 'hospital':
        return l10n.nearbyFacilityCategoryHospital;
      case 'road':
        return l10n.nearbyFacilityCategoryRoad;
      default:
        return l10n.nearbyFacilityCategoryOther;
    }
  }

  static String _label(AppLocalizations l10n, NearbyFacility f) {
    final distance = f.distanceMeters < 1000
        ? l10n.nearbyFacilityDistanceMeters(f.distanceMeters.round())
        : l10n.nearbyFacilityDistanceKm((f.distanceMeters / 1000).toStringAsFixed(1));
    return l10n.nearbyFacilityLabel(distance, f.name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = _label(l10n, facility);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: AppColors.grey700),
    );
    return Semantics(
      button: true,
      label: '${_categoryLabel(l10n, facility.category)}, $label',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surfaceRaised,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: () => launchGoogleMapsNavigation(
            context,
            lat: facility.latitude,
            lng: facility.longitude,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_icon(facility.category), color: AppColors.grey400, size: 16),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.grey300, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
