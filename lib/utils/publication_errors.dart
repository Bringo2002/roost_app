import 'package:roost_app/models/publication_violation.dart';

/// Where a backend publication violation is shown in the listing wizard.
class WizardErrorTarget {
  /// Creates a target: a wizard [step] and the `_errors` [key] of its input.
  const WizardErrorTarget({required this.step, required this.key});

  /// The wizard step (0-based) that contains the input.
  final int step;

  /// The key that input's error text is read from.
  final String key;
}

/// Wizard placement for each backend violation `field`.
///
/// Fields with no entry (the property type, which always has a default, and
/// the owner's phone verification, which is a separate flow) have no input of
/// their own in the wizard, so their messages are reported separately.
const Map<String, WizardErrorTarget> _wizardTargets = {
  'imageUrls': WizardErrorTarget(step: 0, key: 'photos'),
  'title': WizardErrorTarget(step: 1, key: 'title'),
  'price': WizardErrorTarget(step: 1, key: 'price'),
  'location': WizardErrorTarget(step: 2, key: 'locationText'),
  'coordinates': WizardErrorTarget(step: 2, key: 'gps'),
  'landlordPhone': WizardErrorTarget(step: 4, key: 'phone'),
  'caretakerName': WizardErrorTarget(step: 4, key: 'caretakerName'),
  'caretakerPhone': WizardErrorTarget(step: 4, key: 'caretakerPhone'),
};

/// A backend publication failure translated into wizard terms.
class WizardPublicationErrors {
  const WizardPublicationErrors({
    required this.errors,
    required this.firstStep,
    required this.unplacedMessages,
  });

  /// Splits [violations] into per-input errors and the messages that have no
  /// input to attach to.
  factory WizardPublicationErrors.from(List<PublicationViolation> violations) {
    final errors = <String, String>{};
    final unplaced = <String>[];
    int? firstStep;
    for (final violation in violations) {
      final target = _wizardTargets[violation.field];
      if (target == null) {
        unplaced.add(violation.message);
        continue;
      }
      errors.putIfAbsent(target.key, () => violation.message);
      if (firstStep == null || target.step < firstStep) {
        firstStep = target.step;
      }
    }
    return WizardPublicationErrors(
      errors: errors,
      firstStep: firstStep,
      unplacedMessages: unplaced,
    );
  }

  /// Error text by the wizard's `_errors` key.
  final Map<String, String> errors;

  /// The earliest step that has an error to fix, or null when none does.
  final int? firstStep;

  /// Messages for violations that have no input in the wizard.
  final List<String> unplacedMessages;
}
