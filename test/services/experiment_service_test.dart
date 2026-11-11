import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:roost_app/services/experiment_service.dart';

void main() {
  group('ExperimentService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('getVariant returns a valid variant', () async {
      final variant = await ExperimentService.getVariant(
        ExperimentService.onboardingCtaCopy,
      );
      expect(
        ExperimentService.onboardingCtaCopy.variants,
        contains(variant),
      );
    });

    test('getVariant returns same variant on repeated calls', () async {
      final variant1 = await ExperimentService.getVariant(
        ExperimentService.onboardingCtaCopy,
      );
      final variant2 = await ExperimentService.getVariant(
        ExperimentService.onboardingCtaCopy,
      );
      expect(variant1, equals(variant2));
    });

    test('different experiments can yield different variants', () async {
      final ctaVariant = await ExperimentService.getVariant(
        ExperimentService.onboardingCtaCopy,
      );
      final blurVariant = await ExperimentService.getVariant(
        ExperimentService.onboardingPreviewBlur,
      );
      // Both should be valid (may or may not differ — the key thing
      // is that they are from their own experiment's variant list)
      expect(
        ExperimentService.onboardingCtaCopy.variants,
        contains(ctaVariant),
      );
      expect(
        ExperimentService.onboardingPreviewBlur.variants,
        contains(blurVariant),
      );
    });

    test('overrideVariant forces a specific variant', () async {
      await ExperimentService.overrideVariant(
        ExperimentService.onboardingCtaCopy,
        'unlock_my_feed',
      );
      final variant = await ExperimentService.getVariant(
        ExperimentService.onboardingCtaCopy,
      );
      expect(variant, equals('unlock_my_feed'));
    });

    test('resetAll clears all assignments', () async {
      // Assign first
      await ExperimentService.getVariant(ExperimentService.onboardingCtaCopy);
      await ExperimentService.getVariant(ExperimentService.onboardingPreviewBlur);

      // Reset
      await ExperimentService.resetAll();

      // After reset the variant may change (new device ID) — but must still be valid
      final variant = await ExperimentService.getVariant(
        ExperimentService.onboardingCtaCopy,
      );
      expect(
        ExperimentService.onboardingCtaCopy.variants,
        contains(variant),
      );
    });

    test('getAllAssignments returns a map with all experiments', () async {
      final assignments = await ExperimentService.getAllAssignments();
      expect(assignments.keys, containsAll([
        'onboarding_cta_copy',
        'onboarding_preview_blur',
        'onboarding_step_order',
      ]));
      for (final entry in assignments.entries) {
        final exp = ExperimentService.allExperiments.firstWhere(
          (e) => e.name == entry.key,
        );
        expect(exp.variants, contains(entry.value));
      }
    });

    test('logEvent fires onEvent callback with experiment context', () async {
      String? capturedName;
      Map<String, dynamic>? capturedParams;

      ExperimentService.onEvent = (name, params) {
        capturedName = name;
        capturedParams = params;
      };

      await ExperimentService.logEvent('test_event', {'extra': 'data'});

      expect(capturedName, equals('test_event'));
      expect(capturedParams, isNotNull);
      expect(capturedParams!['extra'], equals('data'));
      expect(capturedParams!['timestamp'], isNotNull);
      // Should contain experiment assignments
      expect(capturedParams!.containsKey('onboarding_cta_copy'), isTrue);
      expect(capturedParams!.containsKey('onboarding_preview_blur'), isTrue);

      // Clean up
      ExperimentService.onEvent = null;
    });

    test('persisted events can be retrieved and cleared', () async {
      ExperimentService.onEvent = null; // no external callback
      await ExperimentService.logEvent('test_persist', {'step': 1});
      await ExperimentService.logEvent('test_persist', {'step': 2});

      final events = await ExperimentService.getPersistedEvents();
      expect(events.length, greaterThanOrEqualTo(2));
      expect(events.last['event'], equals('test_persist'));

      await ExperimentService.clearPersistedEvents();
      final cleared = await ExperimentService.getPersistedEvents();
      expect(cleared, isEmpty);
    });
  });

  group('Experiment', () {
    test('all registered experiments have valid definitions', () {
      for (final exp in ExperimentService.allExperiments) {
        expect(exp.name, isNotEmpty);
        expect(exp.variants.length, greaterThanOrEqualTo(2),
            reason: '${exp.name} should have at least 2 variants');
        // No duplicate variants
        expect(exp.variants.toSet().length, equals(exp.variants.length),
            reason: '${exp.name} has duplicate variants');
      }
    });
  });
}
