import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:roost_app/services/auth_service.dart';
import 'package:roost_app/main.dart';
import 'package:roost_app/pages/onboarding/onboarding_page.dart';
import 'package:roost_app/pages/auth/welcome_page.dart';

/// Manages onboarding state, migration, and unified post-auth routing.
///
/// All methods are static — no mutable singleton state is needed. Preferences
/// are read/written directly via [SharedPreferences].
class OnboardingService {
  OnboardingService._();

  // ── Version ────────────────────────────────────────────────────────────

  /// Bump this when the onboarding flow changes structurally.
  static const int currentVersion = 2;

  // ── SharedPreferences keys ─────────────────────────────────────────────

  /// Int: the onboarding schema version the user completed.
  static const String versionKey = 'onboarding_version';

  /// Int: the last completed step index (0-based).
  static const String stepKey = 'onboarding_step';

  /// Bool: whether onboarding has been fully completed.
  static const String completedKey = 'onboarding_completed';

  /// String: selected property type (e.g. '1BR', 'Studio', 'ANY').
  static const String houseTypeKey = 'pref_house_type';

  /// String: display title of the selected budget tier (kept for backward
  /// compatibility with analytics / debugging).
  static const String budgetKey = 'pref_budget';

  /// Double: inclusive lower bound of the selected budget range.
  static const String budgetMinKey = 'pref_budget_min';

  /// Double: inclusive upper bound of the selected budget range.
  static const String budgetMaxKey = 'pref_budget_max';

  /// String: selected move-in timeframe label.
  static const String timeframeKey = 'pref_timeframe';

  /// Double: latitude acquired during the onboarding location step.
  static const String locationLatKey = 'onboarding_location_lat';

  /// Double: longitude acquired during the onboarding location step.
  static const String locationLngKey = 'onboarding_location_lng';

  // ── Startup routing ────────────────────────────────────────────────────

  /// Determines where to route the user when the app launches.
  ///
  /// Called from SplashPage after checking Firebase Auth state.
  static Future<OnboardingDestination> resolveStartup({
    required bool isLoggedIn,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool(completedKey) ?? false;
    final version = prefs.getInt(versionKey);

    if (isLoggedIn && completed) {
      // v1 or v2 complete + logged in → Home. Silently migrate v1 users.
      if (version == null) await prefs.setInt(versionKey, currentVersion);
      return OnboardingDestination.home;
    }

    if (!isLoggedIn && completed) {
      // Completed onboarding but not logged in.
      if (version != null && version >= currentVersion) {
        // Already did v2 onboarding — just needs auth.
        return OnboardingDestination.welcomePage;
      }
      // Old v1 user who logged out, or no version tag → reset and
      // re-onboard with the v2 flow so they get the full experience.
      await prefs.remove(completedKey);
      await prefs.remove(stepKey);
      return OnboardingDestination.onboarding;
    }

    // Never completed or partial → start / resume onboarding.
    final step = prefs.getInt(stepKey) ?? 0;
    return OnboardingDestination.onboardingAtStep(step);
  }

  // ── Post-auth routing ──────────────────────────────────────────────────

  /// Determines where to navigate after any successful authentication.
  ///
  /// [isInOnboardingFlow] should be `true` when auth happens at Step 6 of
  /// the onboarding page (the inline auth step). In that case all
  /// preferences are already persisted and we go straight to Home.
  static Future<OnboardingDestination> getPostAuthDestination(
    AuthResult result, {
    bool isInOnboardingFlow = false,
  }) async {
    if (!result.success) {
      // Shouldn't normally be called on failure, but safe fallback.
      return OnboardingDestination.onboarding;
    }

    final prefs = await SharedPreferences.getInstance();

    if (isInOnboardingFlow) {
      // Auth inside onboarding — all prefs are already saved.
      await prefs.setBool(completedKey, true);
      await prefs.setInt(versionKey, currentVersion);
      return OnboardingDestination.home;
    }

    // Auth from standalone Login/Signup pages (WelcomePage flow).
    final completed = prefs.getBool(completedKey) ?? false;

    if (result.isNewUser && !completed) {
      // Brand new user signing up from WelcomePage → full onboarding.
      return OnboardingDestination.onboarding;
    }

    // Existing user or already completed → Home.
    if (!completed) {
      // Edge case: existing user who never finished onboarding is logging
      // in from WelcomePage. Accept defaults and go to Home.
      await prefs.setBool(completedKey, true);
      await prefs.setInt(versionKey, currentVersion);
    }

    return OnboardingDestination.home;
  }

  // ── Step persistence ───────────────────────────────────────────────────

  /// Persists the completed step index and any associated preference data.
  ///
  /// Called immediately when the user completes each onboarding step so
  /// progress survives app-kill mid-flow.
  ///
  /// ```dart
  /// await OnboardingService.markStepComplete(3, data: {
  ///   OnboardingService.budgetKey: 'Under KES 15,000',
  ///   OnboardingService.budgetMinKey: 0.0,
  ///   OnboardingService.budgetMaxKey: 15000.0,
  /// });
  /// ```
  static Future<void> markStepComplete(
    int step, {
    Map<String, dynamic>? data,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(stepKey, step);

    if (data != null) {
      for (final entry in data.entries) {
        switch (entry.value) {
          case final String v:
            await prefs.setString(entry.key, v);
          case final double v:
            await prefs.setDouble(entry.key, v);
          case final int v:
            await prefs.setInt(entry.key, v);
          case final bool v:
            await prefs.setBool(entry.key, v);
        }
      }
    }
  }

  /// Marks onboarding as fully complete. Called after successful auth in
  /// the onboarding flow.
  static Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(completedKey, true);
    await prefs.setInt(versionKey, currentVersion);
  }

  // ── Query helpers ──────────────────────────────────────────────────────

  /// Returns the step index to resume from when re-entering onboarding.
  static Future<int> getResumeStep() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(stepKey) ?? 0;
  }

  /// Whether onboarding has been fully completed (any version).
  static Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(completedKey) ?? false;
  }
}

// ── Routing destination ────────────────────────────────────────────────────

/// Immutable routing target returned by [OnboardingService] methods.
class OnboardingDestination {
  final _DestinationType _type;

  /// The onboarding step to resume from. Only meaningful when
  /// [_type] is [_DestinationType.onboarding].
  final int resumeStep;

  const OnboardingDestination._(_DestinationType type, [this.resumeStep = 0])
      : _type = type;

  /// Route to the main Home feed.
  static const home = OnboardingDestination._(_DestinationType.home);

  /// Route to the auth gate (for logged-out users who completed onboarding).
  static const welcomePage =
      OnboardingDestination._(_DestinationType.welcomePage);

  /// Route to onboarding from the beginning.
  static const onboarding =
      OnboardingDestination._(_DestinationType.onboarding);

  /// Route to onboarding, resuming at [step].
  static OnboardingDestination onboardingAtStep(int step) =>
      OnboardingDestination._(_DestinationType.onboarding, step);

  /// Build the destination widget for navigation.
  Widget get widget => switch (_type) {
        _DestinationType.home => const HomePage(),
        _DestinationType.welcomePage => const WelcomePage(),
        _DestinationType.onboarding => OnboardingPage(initialStep: resumeStep),
      };
}

enum _DestinationType { home, welcomePage, onboarding }
