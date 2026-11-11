import 'package:roost_app/models/property.dart';
import 'package:roost_app/models/property_verification.dart';

/// How a proof tag should look.
enum ProofTone {
  /// Checked and accepted.
  done,

  /// Submitted and waiting on someone.
  pending,

  /// Rejected or failed; the lister has something to fix.
  problem,

  /// Nothing yet.
  none,
}

/// One small status pill in the verification hub, e.g. "Photos rejected".
class ProofTag {
  /// Creates a tag.
  const ProofTag(this.label, this.tone);

  /// The pill's text.
  final String label;

  /// How the pill is coloured.
  final ProofTone tone;
}

/// The hub's pills for [property], from what the backend says has been
/// checked. "Uploaded" and "approved" are different things and look different:
/// a lister whose photos were rejected needs to see that, not a pill that is
/// merely unticked.
///
/// A property without a [Property.verification] (the backend didn't send one)
/// falls back to the two flags it does send. It is not assumed that the phone
/// is verified.
List<ProofTag> proofTagsFor(Property property) {
  final v = property.verification;
  if (v == null) {
    return [
      ProofTag('GPS', property.gpsVerified ? ProofTone.done : ProofTone.none),
      ProofTag('Doc Proof',
          property.documentVerified ? ProofTone.done : ProofTone.none),
    ];
  }
  return [
    _phone(v.phone),
    _onSite(v.onSite),
    _photos(v.photos),
    _documents(v.documents),
  ];
}

ProofTag _phone(PhoneState state) => switch (state) {
      PhoneState.verified => const ProofTag('Phone', ProofTone.done),
      PhoneState.pending => const ProofTag('Phone pending', ProofTone.pending),
      PhoneState.unverified =>
        const ProofTag('Phone unverified', ProofTone.none),
    };

ProofTag _onSite(OnSiteState state) => switch (state) {
      OnSiteState.passed => const ProofTag('GPS', ProofTone.done),
      OnSiteState.pending => const ProofTag('GPS pending', ProofTone.pending),
      OnSiteState.failed => const ProofTag('GPS failed', ProofTone.problem),
      OnSiteState.notAttempted => const ProofTag('GPS', ProofTone.none),
    };

ProofTag _photos(PhotosState state) => switch (state) {
      PhotosState.approved => const ProofTag('Photos', ProofTone.done),
      PhotosState.submitted ||
      PhotosState.underReview =>
        const ProofTag('Photos pending', ProofTone.pending),
      PhotosState.rejected =>
        const ProofTag('Photos rejected', ProofTone.problem),
      PhotosState.notSubmitted => const ProofTag('Photos', ProofTone.none),
    };

ProofTag _documents(DocumentsState state) => switch (state) {
      DocumentsState.accepted => const ProofTag('Doc Proof', ProofTone.done),
      DocumentsState.uploaded ||
      DocumentsState.underReview =>
        const ProofTag('Doc pending', ProofTone.pending),
      DocumentsState.rejected =>
        const ProofTag('Doc rejected', ProofTone.problem),
      DocumentsState.notSubmitted =>
        const ProofTag('Doc Proof', ProofTone.none),
    };
