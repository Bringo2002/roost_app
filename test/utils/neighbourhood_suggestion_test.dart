import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/utils/neighbourhood_suggestion.dart';

void main() {
  group('shouldApplyAreaSuggestion', () {
    test('fills an empty field', () {
      expect(
        shouldApplyAreaSuggestion(currentText: '', previousSuggestion: null),
        isTrue,
      );
    });

    test('treats a blank field as empty', () {
      expect(
        shouldApplyAreaSuggestion(currentText: '   ', previousSuggestion: null),
        isTrue,
      );
    });

    test('never replaces what the lister typed', () {
      expect(
        shouldApplyAreaSuggestion(
            currentText: 'Westlands, Nairobi', previousSuggestion: null),
        isFalse,
      );
    });

    test('replaces an untouched earlier suggestion', () {
      expect(
        shouldApplyAreaSuggestion(
            currentText: 'Kayole, Nairobi',
            previousSuggestion: 'Kayole, Nairobi'),
        isTrue,
      );
    });

    test('does not replace an earlier suggestion the lister edited', () {
      expect(
        shouldApplyAreaSuggestion(
            currentText: 'Kayole Junction, Nairobi',
            previousSuggestion: 'Kayole, Nairobi'),
        isFalse,
      );
    });
  });
}
