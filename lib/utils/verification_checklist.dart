import 'package:roost_app/models/property_verification.dart';

/// One row of the wizard's "Earn Your VERIFIED Badge" checklist.
class ChecklistRow {
  /// Creates a row.
  const ChecklistRow({required this.complete, required this.subtitle});

  /// Whether this step is done as far as the backend is concerned.
  final bool complete;

  /// What the lister should know or do next.
  final String subtitle;
}

/// The checklist, described from what the backend says has been checked.
///
/// A step is only complete when the backend says so: a phone number that has
/// been typed is not a verified phone, and a document that has been uploaded
/// is not an accepted one. Before the listing's first save there is no
/// backend state yet, so nothing counts as done.
class VerificationChecklist {
  /// Creates a checklist from the backend's [verification], or null before
  /// the listing has been saved.
  const VerificationChecklist(this.verification);

  /// How many steps count towards the badge: phone, on-site check, photos.
  static const int stepsTotal = 3;

  /// The backend's verification state, or null before the first save.
  final PropertyVerification? verification;

  /// Whether the backend says the Verified badge is earned.
  bool get badgeEarned => verification?.badgeEarned ?? false;

  /// How many of the [stepsTotal] steps the backend says are done.
  int get stepsDone =>
      (phone.complete ? 1 : 0) +
      (onSite.complete ? 1 : 0) +
      (photos.complete ? 1 : 0);

  ChecklistRow get phone {
    switch (verification?.phone) {
      case PhoneState.verified:
        return const ChecklistRow(
            complete: true, subtitle: 'Confirmed with a code sent by SMS');
      case PhoneState.pending:
        return const ChecklistRow(
            complete: false, subtitle: 'Code sent. Enter it to finish');
      case PhoneState.unverified:
      case null:
        return const ChecklistRow(
            complete: false,
            subtitle: "You'll confirm this with an SMS code when you publish");
    }
  }

  ChecklistRow get onSite {
    switch (verification?.onSite) {
      case OnSiteState.passed:
        return const ChecklistRow(
            complete: true, subtitle: 'You were checked at the property');
      case OnSiteState.pending:
        return const ChecklistRow(
            complete: false, subtitle: 'Check in progress');
      case OnSiteState.failed:
        return const ChecklistRow(
            complete: false,
            subtitle: "The last check didn't pass. Try again at the property");
      case OnSiteState.notAttempted:
      case null:
        return const ChecklistRow(
            complete: false,
            subtitle:
                'Stand at the property and tap "Confirm your GPS location"');
    }
  }

  ChecklistRow get photos {
    switch (verification?.photos) {
      case PhotosState.approved:
        return const ChecklistRow(
            complete: true, subtitle: 'Approved by Roost');
      case PhotosState.rejected:
        return const ChecklistRow(
            complete: false,
            subtitle: 'Rejected. Upload clearer photos of the property');
      case PhotosState.submitted:
      case PhotosState.underReview:
        return const ChecklistRow(
            complete: false, subtitle: 'Uploaded, waiting for Roost to review');
      case PhotosState.notSubmitted:
      case null:
        return const ChecklistRow(
            complete: false, subtitle: 'Add photos of the property');
    }
  }

  /// Not part of the badge, so it is not counted in [stepsDone].
  ChecklistRow get documents {
    switch (verification?.documents) {
      case DocumentsState.accepted:
        return const ChecklistRow(complete: true, subtitle: 'Accepted');
      case DocumentsState.uploaded:
        return const ChecklistRow(
            complete: false, subtitle: 'Uploaded, not reviewed yet');
      case DocumentsState.underReview:
        return const ChecklistRow(
            complete: false, subtitle: 'Being reviewed');
      case DocumentsState.rejected:
        return const ChecklistRow(
            complete: false, subtitle: 'Rejected. Upload a clearer copy');
      case DocumentsState.notSubmitted:
      case null:
        return const ChecklistRow(
            complete: false,
            subtitle: 'Optional: title deed, utility bill or ID photo');
    }
  }
}
