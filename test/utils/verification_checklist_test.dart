import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/models/property_verification.dart';
import 'package:roost_app/utils/verification_checklist.dart';

PropertyVerification verification({
  PhoneState phone = PhoneState.unverified,
  OnSiteState onSite = OnSiteState.notAttempted,
  PhotosState photos = PhotosState.notSubmitted,
  DocumentsState documents = DocumentsState.notSubmitted,
  bool badgeEarned = false,
}) =>
    PropertyVerification(
      phone: phone,
      location: LocationState.confirmed,
      onSite: onSite,
      photos: photos,
      documents: documents,
      authority: AuthorityState.notEstablished,
      badgeEarned: badgeEarned,
    );

void main() {
  group('before the first save', () {
    const checklist = VerificationChecklist(null);

    test('nothing counts as done', () {
      expect(checklist.stepsDone, 0);
      expect(checklist.badgeEarned, isFalse);
      expect(checklist.phone.complete, isFalse);
      expect(checklist.onSite.complete, isFalse);
      expect(checklist.photos.complete, isFalse);
      expect(checklist.documents.complete, isFalse);
    });
  });

  group('phone', () {
    test('is done only once the backend says it is verified', () {
      expect(
          VerificationChecklist(verification(phone: PhoneState.verified))
              .phone
              .complete,
          isTrue);
      expect(
          VerificationChecklist(verification(phone: PhoneState.unverified))
              .phone
              .complete,
          isFalse);
      expect(
          VerificationChecklist(verification(phone: PhoneState.pending))
              .phone
              .complete,
          isFalse);
    });
  });

  group('on-site check', () {
    test('is done only after it passed', () {
      expect(
          VerificationChecklist(verification(onSite: OnSiteState.passed))
              .onSite
              .complete,
          isTrue);
      for (final state in [
        OnSiteState.notAttempted,
        OnSiteState.pending,
        OnSiteState.failed
      ]) {
        expect(VerificationChecklist(verification(onSite: state)).onSite.complete,
            isFalse,
            reason: '$state');
      }
    });

    test('tells the lister what to do after a failed check', () {
      final row =
          VerificationChecklist(verification(onSite: OnSiteState.failed)).onSite;

      expect(row.subtitle, contains('Try again at the property'));
    });
  });

  group('photos', () {
    test('uploaded photos are waiting for review, not approved', () {
      final row = VerificationChecklist(
              verification(photos: PhotosState.submitted))
          .photos;

      expect(row.complete, isFalse);
      expect(row.subtitle, contains('waiting for Roost to review'));
    });

    test('are done only when approved', () {
      expect(
          VerificationChecklist(verification(photos: PhotosState.approved))
              .photos
              .complete,
          isTrue);
    });

    test('a rejection says so and asks for better photos', () {
      final row = VerificationChecklist(
              verification(photos: PhotosState.rejected))
          .photos;

      expect(row.complete, isFalse);
      expect(row.subtitle, startsWith('Rejected'));
    });
  });

  group('documents', () {
    test('an upload is not an acceptance', () {
      final row = VerificationChecklist(
              verification(documents: DocumentsState.uploaded))
          .documents;

      expect(row.complete, isFalse);
      expect(row.subtitle, 'Uploaded, not reviewed yet');
    });

    test('are done only when accepted', () {
      expect(
          VerificationChecklist(
                  verification(documents: DocumentsState.accepted))
              .documents
              .complete,
          isTrue);
    });

    test('do not count towards the badge steps', () {
      final checklist =
          VerificationChecklist(verification(documents: DocumentsState.accepted));

      expect(checklist.stepsDone, 0);
    });
  });

  group('badge', () {
    test('steps done count phone, on-site check and photos', () {
      final checklist = VerificationChecklist(verification(
        phone: PhoneState.verified,
        onSite: OnSiteState.passed,
        photos: PhotosState.submitted,
      ));

      expect(checklist.stepsDone, 2);
      expect(VerificationChecklist.stepsTotal, 3);
    });

    test("is the backend's decision, not worked out from the steps", () {
      final allDoneButNotEarned = VerificationChecklist(verification(
        phone: PhoneState.verified,
        onSite: OnSiteState.passed,
        photos: PhotosState.approved,
        badgeEarned: false,
      ));
      expect(allDoneButNotEarned.stepsDone, 3);
      expect(allDoneButNotEarned.badgeEarned, isFalse);

      expect(
          VerificationChecklist(verification(badgeEarned: true)).badgeEarned,
          isTrue);
    });
  });
}
