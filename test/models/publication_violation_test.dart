import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/models/publication_violation.dart';

void main() {
  group('PublicationViolation.fromJson', () {
    test('reads field, code and message', () {
      final v = PublicationViolation.fromJson({
        'field': 'imageUrls',
        'code': 'PHOTOS_MIN',
        'message': 'Add at least 3 photos.',
      });

      expect(v.field, 'imageUrls');
      expect(v.code, 'PHOTOS_MIN');
      expect(v.message, 'Add at least 3 photos.');
    });

    test('throws on a missing key rather than defaulting it', () {
      expect(
        () => PublicationViolation.fromJson({
          'field': 'title',
          'message': 'Give your listing a title.',
        }),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
