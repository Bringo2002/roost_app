import 'package:flutter/material.dart';
import 'package:roost_app/theme/app_colors.dart';

/// The text-field decoration shared by the landlord forms: filled surface,
/// rounded borderless field, white focus ring, and destructive error borders.
InputDecoration landlordInputDecoration(
  String label, {
  String? errorText,
  Widget? prefixIcon,
  String? counterText,
}) {
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
    filled: true,
    fillColor: AppColors.surfaceContainer,
    prefixIcon: prefixIcon,
    counterText: counterText,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.white30, width: 1.2),
    ),
    errorText: errorText,
    errorStyle: const TextStyle(color: AppColors.destructive, fontSize: 12),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.destructive, width: 1.2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.destructive, width: 1.6),
    ),
  );
}
