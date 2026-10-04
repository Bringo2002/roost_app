import 'package:flutter_test/flutter_test.dart';

import 'package:roost_app/l10n/generated/app_localizations_en.dart';
import 'package:roost_app/l10n/generated/app_localizations_sw.dart';

void main() {
  group('photo viewer and gallery strings', () {
    test('English position labels fill in current then total', () {
      final l10n = AppLocalizationsEn();
      expect(l10n.photoPositionLabel(2, 5), 'Photo 2 of 5');
      expect(l10n.mediaPositionLabel(2, 5), '2 of 5');
    });

    test('Swahili position labels fill in current then total', () {
      final l10n = AppLocalizationsSw();
      expect(l10n.photoPositionLabel(2, 5), 'Picha 2 kati ya 5');
      expect(l10n.mediaPositionLabel(2, 5), '2 kati ya 5');
    });

    test('toggle labels differ, so each announces what it will do next', () {
      for (final l10n in [AppLocalizationsEn(), AppLocalizationsSw()]) {
        expect(l10n.photoViewerFitToScreen, isNot(l10n.photoViewerFillScreen));
        expect(l10n.heroGalleryMuteVideo, isNot(l10n.heroGalleryUnmuteVideo));
      }
    });
  });
}
