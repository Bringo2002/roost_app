import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight A/B testing infrastructure.
///
/// Assigns users to experiment variants deterministically (hash-based) and
/// persists the assignment so they always see the same variant. Exposes an
/// event logger for conversion tracking that can be wired to any analytics
/// backend (Firebase Analytics, Mixpanel, Amplitude, etc.).
///
/// Usage:
/// ```dart
/// // 1. Define an experiment
/// const ctaCopy = Experiment(
///   name: 'onboarding_cta_copy',
///   variants: ['show_my_homes', 'unlock_my_feed', 'see_whats_waiting'],
/// );
///
/// // 2. Get this user's assigned variant
/// final variant = await ExperimentService.getVariant(ctaCopy);
///
/// // 3. Use the variant
/// Text(variant == 'show_my_homes' ? 'Show My Homes' : 'Unlock My Feed');
///
/// // 4. Log conversion
/// ExperimentService.logEvent('onboarding_completed', {'variant': variant});
/// ```
class ExperimentService {
  ExperimentService._();

  static const String _prefix = 'experiment_';
  static const String _deviceIdKey = 'experiment_device_id';
  static const String _eventsKey = 'experiment_events';

  /// All registered experiments. Add new experiments here.
  static const List<Experiment> allExperiments = [
    onboardingCtaCopy,
    onboardingPreviewBlur,
    onboardingStepOrder,
  ];

  // ── Experiment Definitions ──────────────────────────────────────────

  /// Tests different CTA button copy on the preview step (step 5).
  static const onboardingCtaCopy = Experiment(
    name: 'onboarding_cta_copy',
    variants: ['show_my_homes', 'unlock_my_feed', 'see_whats_waiting'],
  );

  /// Tests the blur intensity on preview cards.
  static const onboardingPreviewBlur = Experiment(
    name: 'onboarding_preview_blur',
    variants: ['heavy_blur', 'light_blur', 'gradient_fade'],
  );

  /// Tests whether showing budget before house type converts better.
  static const onboardingStepOrder = Experiment(
    name: 'onboarding_step_order',
    variants: ['type_first', 'budget_first'],
  );

  // ── Variant Assignment ──────────────────────────────────────────────

  /// Returns the user's assigned variant for the given experiment.
  ///
  /// Assignments are deterministic (hash-based) and cached in
  /// SharedPreferences so the user always sees the same variant.
  static Future<String> getVariant(Experiment experiment) async {
    final prefs = await SharedPreferences.getInstance();

    // Check cached assignment first
    final cached = prefs.getString('$_prefix${experiment.name}');
    if (cached != null && experiment.variants.contains(cached)) {
      return cached;
    }

    // Assign deterministically based on device ID + experiment name
    final deviceId = await _getOrCreateDeviceId(prefs);
    final variant = _assignVariant(deviceId, experiment);

    // Cache the assignment
    await prefs.setString('$_prefix${experiment.name}', variant);

    debugPrint('[Experiment] ${experiment.name} → $variant');
    return variant;
  }

  /// Returns all active experiment assignments as a map.
  /// Useful for attaching to analytics events as user properties.
  static Future<Map<String, String>> getAllAssignments() async {
    final assignments = <String, String>{};
    for (final exp in allExperiments) {
      assignments[exp.name] = await getVariant(exp);
    }
    return assignments;
  }

  /// Force-assigns a specific variant (for QA/debugging only).
  static Future<void> overrideVariant(
    Experiment experiment,
    String variant,
  ) async {
    assert(experiment.variants.contains(variant),
        'Variant "$variant" not in ${experiment.variants}');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix${experiment.name}', variant);
    debugPrint('[Experiment] Override: ${experiment.name} → $variant');
  }

  /// Resets all experiment assignments (for testing/new user).
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final exp in allExperiments) {
      await prefs.remove('$_prefix${exp.name}');
    }
    debugPrint('[Experiment] All assignments reset');
  }

  // ── Event Logging ───────────────────────────────────────────────────

  /// Callback for wiring to an analytics backend.
  /// Set this in main.dart or your analytics setup.
  ///
  /// Example:
  /// ```dart
  /// ExperimentService.onEvent = (name, params) {
  ///   FirebaseAnalytics.instance.logEvent(name: name, parameters: params);
  /// };
  /// ```
  static void Function(String eventName, Map<String, dynamic> params)? onEvent;

  /// Log a conversion or funnel event with experiment context.
  ///
  /// Automatically attaches all experiment assignments as params.
  static Future<void> logEvent(
    String eventName, [
    Map<String, dynamic>? extraParams,
  ]) async {
    final assignments = await getAllAssignments();
    final params = <String, dynamic>{
      ...assignments,
      if (extraParams != null) ...extraParams,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Fire the callback if set
    onEvent?.call(eventName, params);

    // Also persist locally for offline analysis / debugging
    await _persistEvent(eventName, params);

    debugPrint('[Experiment] Event: $eventName $params');
  }

  /// Retrieves locally persisted events (for debugging or batch upload).
  static Future<List<Map<String, dynamic>>> getPersistedEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_eventsKey) ?? [];
    return raw
        .map((e) => json.decode(e) as Map<String, dynamic>)
        .toList();
  }

  /// Clears locally persisted events (call after successful batch upload).
  static Future<void> clearPersistedEvents() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_eventsKey);
  }

  // ── Private Helpers ─────────────────────────────────────────────────

  /// Deterministically assigns a variant using a stable hash.
  static String _assignVariant(String deviceId, Experiment experiment) {
    final input = '$deviceId:${experiment.name}';
    final hash = md5.convert(utf8.encode(input)).toString();
    // Use last 8 hex chars as a number for even distribution
    final bucket = int.parse(hash.substring(hash.length - 8), radix: 16);
    final index = bucket % experiment.variants.length;
    return experiment.variants[index];
  }

  /// Gets or creates a stable device identifier for experiment assignment.
  static Future<String> _getOrCreateDeviceId(SharedPreferences prefs) async {
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null) return existing;

    // Generate a random device ID (UUID-like)
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final id = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    await prefs.setString(_deviceIdKey, id);
    return id;
  }

  /// Persists an event locally for offline analysis.
  static Future<void> _persistEvent(
    String eventName,
    Map<String, dynamic> params,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final events = prefs.getStringList(_eventsKey) ?? [];

    // Cap at 500 events to prevent unbounded growth
    if (events.length >= 500) {
      events.removeRange(0, events.length - 499);
    }

    events.add(json.encode({'event': eventName, ...params}));
    await prefs.setStringList(_eventsKey, events);
  }
}

/// Defines a single A/B test experiment.
class Experiment {
  /// Unique experiment name (e.g. 'onboarding_cta_copy').
  final String name;

  /// The possible variants (e.g. ['control', 'variant_a', 'variant_b']).
  /// Users are evenly distributed across variants.
  final List<String> variants;

  const Experiment({required this.name, required this.variants});
}
