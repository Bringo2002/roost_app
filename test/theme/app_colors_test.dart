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
      // Compare ARGB values rather than the objects: Colors.redAccent is a
      // MaterialAccentColor swatch, and Color equality also checks the
      // runtime type, so a plain Color is never == to a swatch even when
      // every channel matches.
      expect(AppColors.destructive.toARGB32(), Colors.redAccent.toARGB32());
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
      // with AppColors.warning across the landlord screens. Values are
      // compared (not objects) for the swatch-vs-Color reason noted above.
      expect(AppColors.warning.toARGB32(), Colors.amber.toARGB32());
    });
  });

  group('AppColors media overlays', () {
    // Exact-value locks: these replaced raw literals in the gallery and the
    // photo viewer as a no-visual-change refactor.
    test('glass fill and border keep their original alphas', () {
      expect(AppColors.glassFill, Colors.black.withValues(alpha: 0.28));
      expect(AppColors.glassBorder, Colors.white.withValues(alpha: 0.14));
    });

    test('viewer chip and spinner colors equal the Colors they replaced', () {
      expect(AppColors.mediaChipFill, Colors.black54);
      expect(AppColors.mediaChipBorder, Colors.white24);
      expect(AppColors.mediaProgress, Colors.white70);
    });

    test('bottom scrim keeps its original direction, colors and stops', () {
      final gradient = AppColors.mediaBottomScrimGradient;
      expect(gradient.begin, Alignment.bottomCenter);
      expect(gradient.end, Alignment.topCenter);
      expect(gradient.colors, [Colors.black.withValues(alpha: 0.55), Colors.transparent]);
      expect(gradient.stops, [0.0, 0.5]);
    });

    test('grey400 is the value the viewer error state used as Colors.grey', () {
      expect(AppColors.grey400, const Color(0xFF9E9E9E));
    });
  });

  group('AppColors red', () {
    test('error is the single app red', () {
      expect(AppColors.error.toARGB32(), 0xFFFF5252);
    });

    test('destructive is the same red as error', () {
      // The two names exist for readability at call sites; they must never
      // drift apart into two different reds again.
      expect(AppColors.destructive.toARGB32(), AppColors.error.toARGB32());
    });
  });

  group('AppColors deep dark surfaces', () {
    // Exact-value locks: these replaced raw literals as a no-visual-change
    // refactor, so a silent shift would change the admin and landlord
    // verification screens. Compare ARGB ints, not Color objects.
    final expected = <String, List<int>>{
      'zinc900': [AppColors.zinc900.toARGB32(), 0xFF18181B],
      'slate800': [AppColors.slate800.toARGB32(), 0xFF1E293B],
      'slate900': [AppColors.slate900.toARGB32(), 0xFF0F172A],
      'scaffoldDeep': [AppColors.scaffoldDeep.toARGB32(), 0xFF0F0F11],
      'sheetDeep': [AppColors.sheetDeep.toARGB32(), 0xFF121214],
      'indigoLight': [AppColors.indigoLight.toARGB32(), 0xFF818CF8],
    };

    expected.forEach((name, pair) {
      test('$name keeps its original value', () {
        expect(pair[0], pair[1]);
      });
    });
  });
}
