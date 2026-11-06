import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/models/publication_violation.dart';
import 'package:roost_app/utils/publication_errors.dart';

PublicationViolation violation(String field, [String? message]) =>
    PublicationViolation(
      field: field,
      code: '${field.toUpperCase()}_INVALID',
      message: message ?? 'Fix $field.',
    );

void main() {
  group('WizardPublicationErrors.from', () {
    test('places each field on the wizard input that shows it', () {
      final result = WizardPublicationErrors.from([
        violation('imageUrls'),
        violation('title'),
        violation('price'),
        violation('location'),
        violation('coordinates'),
        violation('landlordPhone'),
        violation('caretakerName'),
        violation('caretakerPhone'),
      ]);

      expect(
        result.errors.keys,
        unorderedEquals([
          'photos',
          'title',
          'price',
          'locationText',
          'gps',
          'phone',
          'caretakerName',
          'caretakerPhone',
        ]),
      );
      expect(result.errors['title'], 'Fix title.');
      expect(result.unplacedMessages, isEmpty);
    });

    test('points at the earliest step that has an error', () {
      final result = WizardPublicationErrors.from([
        violation('landlordPhone'),
        violation('price'),
        violation('location'),
      ]);

      expect(result.firstStep, 1);
    });

    test('reports violations with no wizard input as unplaced', () {
      final result = WizardPublicationErrors.from([
        violation('ownerPhone', 'Verify your phone number.'),
        violation('houseType', 'Choose a valid property type.'),
      ]);

      expect(result.errors, isEmpty);
      expect(result.firstStep, isNull);
      expect(
        result.unplacedMessages,
        ['Verify your phone number.', 'Choose a valid property type.'],
      );
    });

    test('keeps the first message when two violations share an input', () {
      final result = WizardPublicationErrors.from([
        violation('coordinates', 'Confirm the property\'s location.'),
        violation('coordinates', 'The confirmed location isn\'t valid.'),
      ]);

      expect(result.errors['gps'], 'Confirm the property\'s location.');
    });

    test('an empty list yields no errors and no step', () {
      final result = WizardPublicationErrors.from(const []);

      expect(result.errors, isEmpty);
      expect(result.firstStep, isNull);
      expect(result.unplacedMessages, isEmpty);
    });
  });

  group('publicationBulletList', () {
    test('puts each message on its own bulleted line', () {
      expect(
        publicationBulletList([
          violation('title', 'Give your listing a title.'),
          violation('imageUrls', 'Add at least 3 photos.'),
        ]),
        '• Give your listing a title.\n• Add at least 3 photos.',
      );
    });

    test('is empty for no violations', () {
      expect(publicationBulletList(const []), '');
    });
  });
}
