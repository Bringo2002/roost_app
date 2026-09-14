import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/country_service.dart';
import 'package:roost_app/theme/app_colors.dart';

/// The persistent bottom bar: price/deposit on the left, a call icon
/// button and a "Chat with Host" CTA on the right, behind a frosted
/// glass blur. This pattern (price pinned + primary action always
/// reachable while scrolling) is the same one Airbnb/Zillow use --
/// already correctly monochrome in the original implementation, so this
/// is mostly an extraction into its own widget plus a switch to the
/// app's shared design tokens instead of inline hex colors.
class PropertyBottomBar extends StatelessWidget {
  const PropertyBottomBar({
    super.key,
    required this.property,
    required this.onCall,
    required this.onChat,
  });

  final Property property;
  final VoidCallback onCall;
  final VoidCallback onChat;

  String _depositText() {
    final raw = property.deposit;
    if (raw == null || raw.trim().isEmpty) return '';
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
    final numVal = num.tryParse(cleaned);
    if (numVal != null && numVal > 0) return 'Deposit: ${CountryService.price(numVal)}';
    return 'Deposit: $raw';
  }

  @override
  Widget build(BuildContext context) {
    final depositText = _depositText();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised.withValues(alpha: 0.93),
        border: Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 20, offset: const Offset(0, -6))],
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                CountryService.price(property.price),
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.4),
                              ),
                              Text(' /mo', style: TextStyle(color: AppColors.grey300, fontSize: 13, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          depositText.isNotEmpty ? depositText : 'Per month',
                          style: TextStyle(color: AppColors.grey500, fontSize: 11, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      color: AppColors.grey800,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.phone_outlined, color: AppColors.white, size: 20),
                      onPressed: onCall,
                      tooltip: 'Call ${property.isDirectLandlord ? 'Landlord' : 'Caretaker'}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: onChat,
                    icon: const Icon(Icons.chat_bubble_outline, size: 17),
                    label: const Text('Chat with Host', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.white,
                      foregroundColor: AppColors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
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
