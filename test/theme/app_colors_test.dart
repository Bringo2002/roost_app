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

  group('AppColors brand exceptions', () {
    test('whatsapp is the official WhatsApp brand green', () {
      expect(AppColors.whatsapp, const Color(0xFF25D366));
    });

    test('destructive is value-identical to Colors.redAccent', () {
      // Guards the no-visual-change guarantee of the red tokenization.
      expect(AppColors.destructive, Colors.redAccent);
    });
  });

  group('AppColors landlord accents', () {
    // Exact-value locks: these replaced raw literals as a no-visual-change
    // refactor, so a silent shift would change the landlord screens.
    const expected = <String, List<Object>>{
      'landlordAccent': [AppColors.landlordAccent, Color(0xFF00C896)],
      'verified': [AppColors.verified, Color(0xFF10B981)],
      'verifiedLight': [AppColors.verifiedLight, Color(0xFF34D399)],
      'indigo': [AppColors.indigo, Color(0xFF6C63FF)],
      'skyBlue': [AppColors.skyBlue, Color(0xFF38BDF8)],
      'blue': [AppColors.blue, Color(0xFF3B82F6)],
      'gold': [AppColors.gold, Color(0xFFFFD700)],
    };

    expected.forEach((name, pair) {
      test('$name keeps its original value', () {
        expect(pair[0], pair[1]);
      });
    });
  });

  group("AppColors.warning", () {
    test("is value-identical to Colors.amber", () {
      // Guards the no-visual-change guarantee of replacing Colors.amber
      // with AppColors.warning across the landlord screens.
      expect(AppColors.warning, Colors.amber);
    });
  });
}
