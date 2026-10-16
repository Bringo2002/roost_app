import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/widgets/landlord/amenity_options.dart';
import 'package:roost_app/widgets/landlord/landlord_input_decoration.dart';

/// The body of the add-property "Amenities & Features" step: a grid of
/// toggleable standard amenities plus a list of landlord-written custom ones.
///
/// Stateless on purpose. The wizard page owns the selections because it also
/// reads them when it builds the review step and the listing payload; this
/// widget only renders them and reports changes through callbacks.
class AmenitiesStep extends StatelessWidget {
  /// Creates the amenities step.
  const AmenitiesStep({
    super.key,
    required this.selected,
    required this.customAmenities,
    required this.onToggle,
    required this.onAddCustom,
    required this.onRemoveCustom,
  });

  /// Which standard amenities are on, keyed by [AmenityOption.key].
  /// A missing key means off.
  final Map<String, bool> selected;

  /// Landlord-written amenities, in the order they were added.
  final List<String> customAmenities;

  /// Called with an amenity's key and its new on/off value when tapped.
  final void Function(String key, bool value) onToggle;

  /// Called with a trimmed, non-empty, not-yet-present custom amenity name.
  final ValueChanged<String> onAddCustom;

  /// Called with the name of the custom amenity whose close icon was tapped.
  final ValueChanged<String> onRemoveCustom;

  Future<void> _addCustom(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _AddAmenityDialog(),
    );
    final text = name?.trim() ?? '';
    if (text.isNotEmpty && !customAmenities.contains(text)) {
      HapticFeedback.lightImpact();
      onAddCustom(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: kAmenityOptions.map((a) {
            final on = selected[a.key] ?? false;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onToggle(a.key, !on);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: (MediaQuery.of(context).size.width - 40 - 12) / 2,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: on
                      ? a.color.withValues(alpha: 0.12)
                      : AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: on
                        ? a.color.withValues(alpha: 0.5)
                        : AppColors.surfaceContainerHigh,
                    width: 1.4,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(a.icon,
                        size: 20, color: on ? a.color : Colors.grey[600]),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        a.label,
                        style: TextStyle(
                          color: on ? Colors.white : Colors.grey[400],
                          fontSize: 13,
                          fontWeight: on ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (on)
                      Icon(Icons.check_circle_rounded,
                          size: 16, color: a.color),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 32),
        const Divider(color: AppColors.surfaceContainerHigh),
        const SizedBox(height: 20),

        // ── Custom Amenities Section ─────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Custom Amenities',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add unique features not listed above',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => _addCustom(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.indigo.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.indigo, width: 1.2),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 16, color: AppColors.indigo),
                    SizedBox(width: 4),
                    Text(
                      'Add Custom',
                      style: TextStyle(
                          color: AppColors.indigo,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (customAmenities.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceContainerHigh),
            ),
            child: Row(
              children: [
                Icon(Icons.stars_outlined, color: Colors.grey[600], size: 20),
                const SizedBox(width: 12),
                Text(
                  'No custom amenities added yet',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: customAmenities.map((custom) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.6), width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars_rounded,
                        size: 16, color: AppColors.gold),
                    const SizedBox(width: 8),
                    Text(
                      custom,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onRemoveCustom(custom);
                      },
                      child: Icon(Icons.close_rounded,
                          size: 16, color: Colors.grey[400]),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Asks for a custom amenity name and pops it as the dialog result (null on
/// cancel). Owns its [TextEditingController] so it is disposed only after the
/// dialog's exit animation has finished.
class _AddAmenityDialog extends StatefulWidget {
  const _AddAmenityDialog();

  @override
  State<_AddAmenityDialog> createState() => _AddAmenityDialogState();
}

class _AddAmenityDialogState extends State<_AddAmenityDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Row(
        children: [
          Icon(Icons.stars_rounded, color: AppColors.gold, size: 22),
          SizedBox(width: 10),
          Text('Add Custom Amenity',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              'Enter any amenity or special feature available at your property:',
              style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: landlordInputDecoration(
                'Amenity Name (e.g. Sauna, EV Charger)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.indigo,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.pop(context, _controller.text),
          child:
              const Text('Add Amenity', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
