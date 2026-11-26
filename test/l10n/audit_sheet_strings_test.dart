import 'package:flutter_test/flutter_test.dart';

import 'package:roost_app/l10n/generated/app_localizations_en.dart';
import 'package:roost_app/l10n/generated/app_localizations_sw.dart';

void main() {
  group('admin audit sheet strings', () {
    test('English placeholders fill in', () {
      final l10n = AppLocalizationsEn();
      expect(l10n.auditLandlordPhone('+254700000001'), 'Phone: +254700000001');
      expect(l10n.auditDocsTitle(2), 'ATTACHED OWNERSHIP PROOFS (2)');
      expect(l10n.auditPhotosTitle(4), 'LISTING PHOTOS (4)');
      expect(l10n.auditDocProofLabel(3), 'Doc Proof #3');
    });

    test('Swahili placeholders fill in', () {
      final l10n = AppLocalizationsSw();
      expect(l10n.auditLandlordPhone('+254700000001'), 'Simu: +254700000001');
      expect(l10n.auditDocsTitle(2), 'NYARAKA ZA UMILIKI ZILIZOAMBATISHWA (2)');
      expect(l10n.auditPhotosTitle(4), 'PICHA ZA TANGAZO (4)');
      expect(l10n.auditDocProofLabel(3), 'Uthibitisho wa Hati #3');
    });

    test('every fixed string has its own Swahili text, not the English',
        () {
      final en = AppLocalizationsEn();
      final sw = AppLocalizationsSw();
      final pairs = <String, List<String>>{
        'auditLandlordFallbackName': [
          en.auditLandlordFallbackName,
          sw.auditLandlordFallbackName,
        ],
        'auditLandlordNoPhone': [
          en.auditLandlordNoPhone,
          sw.auditLandlordNoPhone,
        ],
        'auditScreeningTitle': [
          en.auditScreeningTitle,
          sw.auditScreeningTitle,
        ],
        'auditScreeningNotRecorded': [
          en.auditScreeningNotRecorded,
          sw.auditScreeningNotRecorded,
        ],
        'auditScreeningExplanation': [
          en.auditScreeningExplanation,
          sw.auditScreeningExplanation,
        ],
        'auditDocsEmpty': [
          en.auditDocsEmpty,
          sw.auditDocsEmpty,
        ],
        'auditPhotosEmpty': [
          en.auditPhotosEmpty,
          sw.auditPhotosEmpty,
        ],
      };
      for (final entry in pairs.entries) {
        expect(
          entry.value[1],
          isNot(entry.value[0]),
          reason: '${entry.key} is untranslated',
        );
      }
    });
  });
}
