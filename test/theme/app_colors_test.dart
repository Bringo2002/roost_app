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

  group('AppColors remaining accents and surfaces', () {
    // Exact-value locks: these replaced raw literals as a no-visual-change
    // refactor. Compare ARGB ints, not Color objects.
    final expected = <String, List<int>>{
      'shadowCard': [AppColors.shadowCard.toARGB32(), 0x28000000],
      'shadowControl': [AppColors.shadowControl.toARGB32(), 0x40000000],
      'modalBarrier': [AppColors.modalBarrier.toARGB32(), 0x99000000],
      'verifiedTint': [AppColors.verifiedTint.toARGB32(), 0x3010B981],
      'skyBlueTint': [AppColors.skyBlueTint.toARGB32(), 0x2038BDF8],
      'notificationChat': [AppColors.notificationChat.toARGB32(), 0xFF1D85FC],
      'notificationBooking': [AppColors.notificationBooking.toARGB32(), 0xFF34C759],
      'notificationListing': [AppColors.notificationListing.toARGB32(), 0xFFFF9500],
      'notificationSystem': [AppColors.notificationSystem.toARGB32(), 0xFFAF52DE],
      'blueLight': [AppColors.blueLight.toARGB32(), 0xFF60A5FA],
      'skyBlueDark': [AppColors.skyBlueDark.toARGB32(), 0xFF0284C7],
      'verifiedDark': [AppColors.verifiedDark.toARGB32(), 0xFF064E3B],
      'verifiedDarkest': [AppColors.verifiedDarkest.toARGB32(), 0xFF022C22],
      'dialogDeep': [AppColors.dialogDeep.toARGB32(), 0xFF141416],
      'cardDeep': [AppColors.cardDeep.toARGB32(), 0xFF1E1E22],
      'placeholderDeep': [AppColors.placeholderDeep.toARGB32(), 0xFF2C2C32],
      'infoNavy': [AppColors.infoNavy.toARGB32(), 0xFF0F2942],
      'cardNavy': [AppColors.cardNavy.toARGB32(), 0xFF0D1B2A],
      'borderNavy': [AppColors.borderNavy.toARGB32(), 0xFF1B3A4B],
      'cardIndigoDark': [AppColors.cardIndigoDark.toARGB32(), 0xFF1A1A2E],
      'borderIndigoDark': [AppColors.borderIndigoDark.toARGB32(), 0xFF2A2A4A],
      'borderDeep': [AppColors.borderDeep.toARGB32(), 0xFF2A2A2A],
      'orange': [AppColors.orange.toARGB32(), 0xFFFF9F43],
      'lightBlue': [AppColors.lightBlue.toARGB32(), 0xFF4FC3F7],
      'coral': [AppColors.coral.toARGB32(), 0xFFFF6B6B],
      'cyan': [AppColors.cyan.toARGB32(), 0xFF00E5FF],
    };

    expected.forEach((name, pair) {
      test('$name keeps its original value', () {
        expect(pair[0], pair[1]);
      });
    });

    test('unreadDot shares the chat blue', () {
      expect(AppColors.unreadDot.toARGB32(), AppColors.notificationChat.toARGB32());
    });
  });

  group('AppColors status colors match the Material colors they replaced', () {
    // Compare ARGB ints, not Color objects: the Material colors are swatches
    // and Color equality also checks the runtime type.
    test('success equals Colors.green', () {
      expect(AppColors.success.toARGB32(), Colors.green.toARGB32());
    });

    test('successAccent equals Colors.greenAccent', () {
      expect(AppColors.successAccent.toARGB32(), Colors.greenAccent.toARGB32());
    });

    test('warningAccent equals Colors.orangeAccent', () {
      expect(AppColors.warningAccent.toARGB32(), Colors.orangeAccent.toARGB32());
    });
  });
}
