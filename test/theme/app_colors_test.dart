import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/theme/app_colors.dart';

void main() {
  group('AppColors neutral container ramp', () {
    // Exact-value locks: these tokens replaced raw literals across the app
    // as a no-visual-change refactor, so a silent shift would be a visible
    // regression everywhere they are used.
    test('surfaceContainer is the original card fill', () {
      expect(AppColors.surfaceContainer, const Color(0xFF1C1C1E));
    });

    test('surfaceContainerHigh is the original hairline/skeleton grey', () {
      expect(AppColors.surfaceContainerHigh, const Color(0xFF2C2C2E));
    });

    test('surfaceContainerHighest is the original strong stroke grey', () {
      expect(AppColors.surfaceContainerHighest, const Color(0xFF3A3A3C));
    });

    test('ramp gets strictly lighter from container to highest', () {
      final luminances = [
        AppColors.surfaceContainer,
        AppColors.surfaceContainerHigh,
        AppColors.surfaceContainerHighest,
      ].map((c) => c.computeLuminance()).toList();

      expect(luminances[0], lessThan(luminances[1]));
      expect(luminances[1], lessThan(luminances[2]));
    });
  });
}
