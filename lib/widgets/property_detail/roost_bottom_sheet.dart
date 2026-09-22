import 'package:flutter/material.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/theme/app_text_styles.dart';

/// Shared chrome for Roost's modal bottom sheets: drag handle, title,
/// subtitle, and consistent padding/radius/background. Previously the
/// community-check and report sheets each hand-rolled this same
/// scaffolding independently.
///
/// Usage:
/// ```dart
/// RoostBottomSheet.show(
///   context: context,
///   title: 'Report Listing',
///   subtitle: 'Help us keep Roost safe and verified.',
///   builder: (sheetContext) => MyFormContent(),
/// );
/// ```
class RoostBottomSheet {
  RoostBottomSheet._();

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required String subtitle,
    required WidgetBuilder builder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: AppColors.surfaceRaised,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: AppColors.grey700,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Text(title, style: AppTextStyles.title.copyWith(fontSize: 19, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(subtitle, style: AppTextStyles.caption.copyWith(height: 1.4)),
                  const SizedBox(height: 18),
                  builder(ctx),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A full-width primary action button matching the sheet's monochrome
/// language, with a built-in loading state so callers don't re-implement
/// the spinner-swap dance each time.
class RoostSheetSubmitButton extends StatelessWidget {
  const RoostSheetSubmitButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.isSubmitting,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isSubmitting;

  /// Destructive actions (e.g. submitting a report) get a subdued dark
  /// treatment instead of the bright primary fill -- still monochrome,
  /// just visually distinct from an affirmative action like "Submit".
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isSubmitting ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDestructive ? AppColors.grey800 : AppColors.white,
          foregroundColor: isDestructive ? AppColors.white : AppColors.black,
          disabledBackgroundColor:
              (isDestructive ? AppColors.grey800 : AppColors.white).withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: isSubmitting
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isDestructive ? AppColors.white : AppColors.black,
                ),
              )
            : Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }
}
