import 'package:flutter/material.dart';

/// Roost's monochrome brand palette. Black, white, and a grey scale, with a
/// small set of documented, named exceptions where color carries meaning
/// (favorite heart, WhatsApp, destructive red, and the landlord-surface
/// accents). Every widget should pull colors from here rather than
/// referencing `Colors.xxx` or raw hex literals directly.
class AppColors {
  AppColors._();

  // Core brand
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);

  // Surfaces
  static const Color background = black;
  static const Color surface = Color(0xFF121212);
  static const Color surfaceRaised = Color(0xFF1A1A1A);

  // Neutral container ramp (iOS-style dark system greys). Used for cards,
  // text-field fills, sheets and snackbars (`surfaceContainer`), hairline
  // borders, dividers and skeleton bases (`surfaceContainerHigh`), and
  // stronger strokes or unselected foregrounds (`surfaceContainerHighest`).
  // Values are intentionally kept byte-identical to the literals they
  // replaced; consolidating them into the grey scale above is a separate,
  // visible design decision.
  static const Color surfaceContainer = Color(0xFF1C1C1E);
  static const Color surfaceContainerHigh = Color(0xFF2C2C2E);
  static const Color surfaceContainerHighest = Color(0xFF3A3A3C);

  // Greys (100 = lightest, 900 = darkest)
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFE0E0E0);
  static const Color grey300 = Color(0xFFBDBDBD);
  static const Color grey400 = Color(0xFF9E9E9E);
  static const Color grey500 = Color(0xFF757575);
  static const Color grey600 = Color(0xFF616161);
  static const Color grey700 = Color(0xFF424242);
  static const Color grey800 = Color(0xFF2C2C2C);
  static const Color grey900 = Color(0xFF1E1E1E);

  // Text
  static const Color textPrimary = white;
  static const Color textSecondary = grey300;
  static const Color textTertiary = grey500;

  // Borders / dividers
  static const Color border = grey700;
  static const Color divider = grey800;

  // Overlays (used sparingly, e.g. favorite button backing, image scrims)
  static Color scrimDark = black.withValues(alpha: 0.45);
  static Color scrimLight = white.withValues(alpha: 0.12);

  // Shadow
  static Color shadow = black.withValues(alpha: 0.06);

  // ─── Media overlays (listing gallery and full-screen photo viewer) ───
  // Values are identical to the raw literals they replaced.

  /// Frosted-glass fill for controls floating over a photo (the gallery's
  /// counter pill and its circular icon buttons).
  static Color glassFill = black.withValues(alpha: 0.28);

  /// Hairline border that goes with [glassFill].
  static Color glassBorder = white.withValues(alpha: 0.14);

  /// Counter pill over the full-screen photo viewer. Heavier than the glass
  /// pair above; the two are kept distinct because unifying them would be a
  /// visible design change. Equal to `Colors.black54`.
  static const Color mediaChipFill = Color(0x8A000000);

  /// Border that goes with [mediaChipFill]. Equal to `Colors.white24`.
  static const Color mediaChipBorder = Color(0x3DFFFFFF);

  /// Loading spinner over the viewer's black background. Equal to
  /// `Colors.white70`.
  static const Color mediaProgress = Color(0xB3FFFFFF);

  /// Bottom-up scrim that keeps the gallery's page dots legible over bright
  /// photos.
  static LinearGradient mediaBottomScrimGradient = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [black.withValues(alpha: 0.55), const Color(0x00000000)],
    stops: const [0.0, 0.5],
  );

  // Accent — pure white monochrome
  static const Color accent = Colors.white;
  static const Color accentMuted = Color(0xFFE0E0E0);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);

  /// Brighter green (Material greenAccent) for earned / complete highlights,
  /// where plain [success] is too quiet on the dark surfaces.
  static const Color successAccent = Color(0xFF69F0AE);

  /// Brighter orange (Material orangeAccent) for non-blocking notices.
  static const Color warningAccent = Color(0xFFFFAB40);

  /// The app's single red, for errors, validation failures and destructive
  /// actions (delete, clear, reject). Red is kept as a deliberate exception
  /// to the monochrome palette because it is the universally understood
  /// signal for "danger"; a grey delete button or error message is easy to
  /// miss. Previously `error` (0xFFF44336) and `destructive` (0xFFFF5252)
  /// were two near-identical reds; they are unified on the brighter one,
  /// which is also the one most screens already showed and reads better on
  /// the dark surfaces.
  static const Color error = Color(0xFFFF5252);

  /// Online-presence dot (avatar indicator).
  static const Color onlineAccent = Colors.white;

  /// The one deliberate exception to "no accent colors": a filled red
  /// heart is a near-universal, instantly-recognizable "saved" signal
  /// across major apps (Instagram, X, etc.), and a monochrome heart reads
  /// to users as unselected/inactive regardless of fill state. Named
  /// explicitly and used only for this one purpose, rather than
  /// referencing `Colors.redAccent` directly wherever a favorite icon is
  /// drawn -- so the decision is documented and grep-able.
  static const Color favoriteActive = Colors.redAccent;

  /// Second deliberate exception to "no accent colors": the WhatsApp
  /// contact action. Its recognizable brand green is what lets users spot
  /// the WhatsApp option at a glance among the other contact buttons.
  /// Named here, rather than left as a raw hex at its call site, so the
  /// decision is documented and grep-able.
  static const Color whatsapp = Color(0xFF25D366);

  /// Alias of [error] for destructive actions, kept so call sites read by
  /// intent. Value is identical to `Colors.redAccent`.
  static const Color destructive = error;

  // ─── Landlord-surface accents ───────────────────────────────────────
  // Intentionally colored: the landlord flows (listing creation,
  // verification, dashboard) use color to signal progress, verification
  // tier and category. Values are byte-identical to the literals they
  // replaced.

  /// Mint accent for landlord primary actions, progress and confirmation.
  static const Color landlordAccent = Color(0xFF00C896);

  /// Emerald for verified / completed states.
  static const Color verified = Color(0xFF10B981);

  /// Lighter emerald for the active or highlighted verified state.
  static const Color verifiedLight = Color(0xFF34D399);

  static const Color indigo = Color(0xFF6C63FF);
  static const Color skyBlue = Color(0xFF38BDF8);
  static const Color blue = Color(0xFF3B82F6);
  static const Color gold = Color(0xFFFFD700);

  // --- Deep dark surfaces (zinc / slate) --------------------------------
  // A separate near-black family used by the admin and landlord
  // verification screens for scaffolds, cards and header gradients. Kept
  // byte-identical to the literals they replaced; folding them into the
  // neutral ramp above would be a separate, visible design decision.

  /// Tailwind zinc-900: cards, panels and gradient ends.
  static const Color zinc900 = Color(0xFF18181B);

  /// Tailwind slate-800 / slate-900: header gradient stops.
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);

  /// Deepest background: scaffolds and app bars on the admin and landlord
  /// verification screens.
  static const Color scaffoldDeep = Color(0xFF0F0F11);

  /// Modal bottom-sheet background on the admin audit sheet.
  static const Color sheetDeep = Color(0xFF121214);

  /// Lighter indigo accent (cf. [indigo]) for small icons.
  static const Color indigoLight = Color(0xFF818CF8);

  // --- Remaining accents and surfaces ----------------------------------
  // The long tail of one-off colors, named so no raw hex remains outside
  // this file. Every value is byte-identical to the literal it replaced.

  // Shadows and scrims
  /// Soft drop shadow under cards and their skeletons.
  static const Color shadowCard = Color(0x28000000);
  /// Shadow under small floating circular controls.
  static const Color shadowControl = Color(0x40000000);
  /// Barrier behind modal bottom sheets.
  static const Color modalBarrier = Color(0x99000000);

  // Tints
  /// [verified] at ~19% opacity, for tinted badge backgrounds.
  static const Color verifiedTint = Color(0x3010B981);
  /// [skyBlue] at ~13% opacity, for tinted icon backgrounds.
  static const Color skyBlueTint = Color(0x2038BDF8);

  // Notification types
  /// Chat notification icon background.
  static const Color notificationChat = Color(0xFF1D85FC);
  /// Booking notification icon background.
  static const Color notificationBooking = Color(0xFF34C759);
  /// Listing notification icon background.
  static const Color notificationListing = Color(0xFFFF9500);
  /// System notification icon background.
  static const Color notificationSystem = Color(0xFFAF52DE);

  // Accent shades
  /// Lighter blue (cf. [blue]) for the mid verification tier icon.
  static const Color blueLight = Color(0xFF60A5FA);
  /// Darker sky blue (cf. [skyBlue]) for outlined-button borders.
  static const Color skyBlueDark = Color(0xFF0284C7);
  /// Deep emerald (cf. [verified]) for gradient starts.
  static const Color verifiedDark = Color(0xFF064E3B);
  /// Deepest emerald, the end of the tier-3 header gradient.
  static const Color verifiedDarkest = Color(0xFF022C22);

  // Tinted dark cards
  /// Listing-completion dialog background.
  static const Color dialogDeep = Color(0xFF141416);
  /// Card on the listing-completion dialog.
  static const Color cardDeep = Color(0xFF1E1E22);
  /// Thumbnail placeholder background.
  static const Color placeholderDeep = Color(0xFF2C2C32);
  /// Navy info box background.
  static const Color infoNavy = Color(0xFF0F2942);
  /// Navy card background.
  static const Color cardNavy = Color(0xFF0D1B2A);
  /// Border for the navy card.
  static const Color borderNavy = Color(0xFF1B3A4B);
  /// Dark indigo card background.
  static const Color cardIndigoDark = Color(0xFF1A1A2E);
  /// Border for the dark indigo card.
  static const Color borderIndigoDark = Color(0xFF2A2A4A);
  /// Neutral border on deep dark cards.
  static const Color borderDeep = Color(0xFF2A2A2A);

  // Other accents
  /// Orange accent for the listing-intro checklist.
  static const Color orange = Color(0xFFFF9F43);
  /// Light blue accent for the listing-intro checklist.
  static const Color lightBlue = Color(0xFF4FC3F7);
  /// Confetti coral.
  static const Color coral = Color(0xFFFF6B6B);
  /// Confetti cyan.
  static const Color cyan = Color(0xFF00E5FF);

  /// Unread indicator dot; shares the chat blue.
  static const Color unreadDot = notificationChat;

  // ─── Gradient Presets ────────────────────────────────────────────────

  /// Subtle surface gradient for premium card backgrounds.
  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A1A1A), Color(0xFF121212)],
  );

  /// High-contrast gradient for CTA buttons and emphasis elements.
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [white, Color(0xFFE0E0E0)],
  );

  /// Bottom-to-top scrim gradient for image overlays.
  static const LinearGradient imageScrimGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00000000), Color(0x99000000)],
    stops: [0.4, 1.0],
  );

  /// Left-to-right red gradient for destructive swipe actions (remove,
  /// delete). No existing flat color token captures this two-tone
  /// effect, so it's named here rather than left as raw hex at its one
  /// call site.
  static const LinearGradient destructiveGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
  );

  // ─── Shadow Presets ─────────────────────────────────────────────────

  /// Subtle shadow for flat elements needing minimal depth.
  static final List<BoxShadow> shadowSm = [
    BoxShadow(
      color: black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  /// Medium shadow for cards and elevated containers.
  static final List<BoxShadow> shadowMd = [
    BoxShadow(
      color: black.withValues(alpha: 0.06),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  /// Large shadow for modals, bottom sheets, and overlays.
  static final List<BoxShadow> shadowLg = [
    BoxShadow(
      color: black.withValues(alpha: 0.12),
      blurRadius: 40,
      offset: const Offset(0, 16),
    ),
  ];

  // ─── Animation Duration Tokens ──────────────────────────────────────

  /// Quick micro-interactions: button presses, icon toggles.
  static const Duration durationFast = Duration(milliseconds: 150);

  /// Standard transitions: card reveals, filter changes.
  static const Duration durationMedium = Duration(milliseconds: 300);

  /// Deliberate animations: page transitions, gauge fills.
  static const Duration durationSlow = Duration(milliseconds: 500);

  /// Extended animations: chart draws, trust score count-up.
  static const Duration durationGauge = Duration(milliseconds: 900);

  // ─── Spacing Scale (extends AppSpacing for color-coupled layouts) ───

  /// Standard stagger delay between sequential list item animations.
  static const Duration staggerDelay = Duration(milliseconds: 50);
}
