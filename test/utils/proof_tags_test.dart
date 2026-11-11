import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/models/property_verification.dart';
import 'package:roost_app/utils/proof_tags.dart';

Property property({
  PropertyVerification? verification,
  bool gpsVerified = false,
  bool documentVerified = false,
}) =>
    Property.fromJson({
      'title': 'Sunny 1BR',
      'description': 'Bright',
      'location': 'Kilimani, Nairobi',
      'price': 25000.0,
      'bedrooms': 1,
      'type': 'RENTAL',
      'landlordPhone': '+254712345678',
      'available': true,
      'gpsVerified': gpsVerified,
      'documentVerified': documentVerified,
    }).copyWith(verification: verification);

PropertyVerification verification({
  PhoneState phone = PhoneState.unverified,
  OnSiteState onSite = OnSiteState.notAttempted,
  PhotosState photos = PhotosState.notSubmitted,
  DocumentsState documents = DocumentsState.notSubmitted,
}) =>
    PropertyVerification(
      phone: phone,
      location: LocationState.confirmed,
      onSite: onSite,
      photos: photos,
      documents: documents,
      authority: AuthorityState.notEstablished,
      badgeEarned: false,
    );

Map<String, ProofTone> tones(Property p) =>
    {for (final tag in proofTagsFor(p)) tag.label: tag.tone};

void main() {
  group('proofTagsFor with the backend verification', () {
    test('a fresh listing has nothing done, and says the phone is unverified',
        () {
      final tags = proofTagsFor(property(verification: verification()));

      expect(tags.map((t) => t.label),
          ['Phone unverified', 'GPS', 'Photos', 'Doc Proof']);
      expect(tags.every((t) => t.tone == ProofTone.none), isTrue);
    });

    test('everything verified shows every tag as done', () {
      final tags = proofTagsFor(property(
        verification: verification(
          phone: PhoneState.verified,
          onSite: OnSiteState.passed,
          photos: PhotosState.approved,
          documents: DocumentsState.accepted,
        ),
      ));

      expect(tags.map((t) => t.label), ['Phone', 'GPS', 'Photos', 'Doc Proof']);
      expect(tags.every((t) => t.tone == ProofTone.done), isTrue);
    });

    test('uploaded photos and documents are pending, not done', () {
      final result = tones(property(
        verification: verification(
          photos: PhotosState.submitted,
          documents: DocumentsState.uploaded,
        ),
      ));

      expect(result['Photos pending'], ProofTone.pending);
      expect(result['Doc pending'], ProofTone.pending);
    });

    test('a rejection is a problem the lister can see', () {
      final result = tones(property(
        verification: verification(
          photos: PhotosState.rejected,
          documents: DocumentsState.rejected,
          onSite: OnSiteState.failed,
        ),
      ));

      expect(result['Photos rejected'], ProofTone.problem);
      expect(result['Doc rejected'], ProofTone.problem);
      expect(result['GPS failed'], ProofTone.problem);
    });

    test('reserved in-progress states are shown as pending', () {
      final result = tones(property(
        verification: verification(
          phone: PhoneState.pending,
          onSite: OnSiteState.pending,
          photos: PhotosState.underReview,
          documents: DocumentsState.underReview,
        ),
      ));

      expect(result['Phone pending'], ProofTone.pending);
      expect(result['GPS pending'], ProofTone.pending);
      expect(result['Photos pending'], ProofTone.pending);
      expect(result['Doc pending'], ProofTone.pending);
    });
  });

  group('proofTagsFor without a verification', () {
    test('falls back to the flags it has and never claims a verified phone',
        () {
      final tags = proofTagsFor(property(gpsVerified: true));

      expect(tags.map((t) => t.label), ['GPS', 'Doc Proof']);
      expect(tags[0].tone, ProofTone.done);
      expect(tags[1].tone, ProofTone.none);
    });

    test('shows documents as done when the flag says so', () {
      final tags = proofTagsFor(property(documentVerified: true));

      expect(tags[1].tone, ProofTone.done);
    });
  });
}
