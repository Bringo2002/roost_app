import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/models/identity_review.dart';

void main() {
  group('IdentityDocument.fromJson', () {
    test('reads every field the admin endpoint sends', () {
      final doc = IdentityDocument.fromJson({
        'id': 11,
        'docType': 'NATIONAL_ID_FRONT',
        'status': 'SUBMITTED',
        'contentType': 'image/jpeg',
        'sizeBytes': 2048,
        'uploadedAt': '2026-11-16T09:00:00',
        'rejectReason': null,
      });

      expect(doc.id, 11);
      expect(doc.docType, 'NATIONAL_ID_FRONT');
      expect(doc.status, 'SUBMITTED');
      expect(doc.contentType, 'image/jpeg');
      expect(doc.sizeBytes, 2048);
      expect(doc.rejectReason, isNull);
    });

    test('knows images from PDFs and rejected documents', () {
      final image = IdentityDocument.fromJson({'id': 1, 'contentType': 'image/png'});
      final pdf = IdentityDocument.fromJson({'id': 2, 'contentType': 'application/pdf'});
      final rejected = IdentityDocument.fromJson({'id': 3, 'status': 'REJECTED', 'rejectReason': 'Blurry'});

      expect(image.isImage, isTrue);
      expect(image.isPdf, isFalse);
      expect(pdf.isPdf, isTrue);
      expect(pdf.isImage, isFalse);
      expect(rejected.wasRejected, isTrue);
      expect(rejected.rejectReason, 'Blurry');
      expect(image.wasRejected, isFalse);
    });

    test('labels the identity document types a person can read', () {
      String label(String type) => IdentityDocument.fromJson({'id': 1, 'docType': type}).label;

      expect(label('NATIONAL_ID_FRONT'), 'National ID (front)');
      expect(label('NATIONAL_ID_BACK'), 'National ID (back)');
      expect(label('PASSPORT'), 'Passport');
      expect(label('SOMETHING_ELSE'), 'SOMETHING_ELSE');
    });
  });

  group('IdentityReview.fromJson', () {
    test('reads the lister and their documents', () {
      final review = IdentityReview.fromJson({
        'userId': 7,
        'name': '  Mama Wanjiku ',
        'documents': [
          {'id': 11, 'docType': 'NATIONAL_ID_FRONT', 'contentType': 'image/jpeg'},
          {'id': 12, 'docType': 'NATIONAL_ID_BACK', 'contentType': 'image/jpeg'},
        ],
      });

      expect(review.userId, 7);
      expect(review.name, 'Mama Wanjiku');
      expect(review.documents.map((d) => d.id), [11, 12]);
    });

    test('a missing name or document list does not break the queue', () {
      final review = IdentityReview.fromJson({'userId': 8, 'name': null});

      expect(review.name, 'Unnamed lister');
      expect(review.documents, isEmpty);
    });
  });
}
