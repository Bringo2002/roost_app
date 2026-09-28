import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:roost_app/l10n/generated/app_localizations.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/models/user.dart';
import 'package:roost_app/widgets/property/property_card.dart';
import 'package:roost_app/widgets/property/property_image.dart';

/// Records pushed routes without ever letting their pages actually build.
///
/// PropertyCard's default (non-overridden) Chat/Navigate/tap-to-view
/// behaviors push real pages -- ChatRoomPage, InAppMapPage,
/// PropertyDetailPage -- that carry their own heavy dependencies (chat
/// sockets, Google Maps platform views, auth-backed API calls) this suite
/// deliberately does not stand up. A `MaterialPageRoute`'s `builder` is
/// only invoked when Flutter actually paints that part of the tree, which
/// requires a `pump()` after the push. As long as tests assert on this
/// observer *without* pumping afterward, "navigation was attempted" is
/// verified without ever constructing the destination page.
class _RecordingNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
    super.didPush(route, previousRoute);
  }
}

/// Fake for `url_launcher`'s platform interface so `_callLandlord`'s
/// default dialer path is testable without a real platform channel.
/// `UrlLauncherPlatform` ships default `UnimplementedError` bodies
/// specifically so implementers only need to override what they use.
class _FakeUrlLauncher extends UrlLauncherPlatform {
  _FakeUrlLauncher({this.succeeds = true});

  final bool succeeds;
  final List<String> launchedUrls = [];

  // Abstract getter with no default body in url_launcher_platform_interface
  // 2.3.x; this fake never renders a Link widget, so null is correct.
  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrls.add(url);
    return succeeds;
  }
}

Property _property({
  int? id = 1,
  String title = 'Cozy Bedsitter',
  double price = 25000,
  int bedrooms = 1,
  int bathrooms = 1,
  bool available = true,
  bool verified = false,
  List<String> riskFlags = const [],
  String? imageUrl,
  List<String> imageUrls = const [],
  String? listedAt,
  String managerRole = 'LANDLORD',
  User? owner,
  String landlordPhone = '+254712345678',
}) {
  return Property(
    id: id,
    title: title,
    description: 'A lovely place to call home.',
    location: 'Kilimani, Nairobi',
    price: price,
    bedrooms: bedrooms,
    type: 'RENTAL',
    landlordPhone: landlordPhone,
    available: available,
    verified: verified,
    riskFlags: riskFlags,
    imageUrl: imageUrl,
    imageUrls: imageUrls,
    listedAt: listedAt,
    bathrooms: bathrooms,
    managerRole: managerRole,
    owner: owner,
  );
}

Widget _wrap(Widget child, {NavigatorObserver? observer}) {
  return MaterialApp(
    navigatorObservers: observer == null ? const [] : [observer],
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('PropertyCard rendering', () {
    testWidgets('shows title, formatted price, and location', (tester) async {
      await tester.pumpWidget(_wrap(PropertyCard(property: _property(title: 'Sunset Apartments', price: 32000))));

      expect(find.text('Sunset Apartments'), findsOneWidget);
      // KES formatting is locale-driven (CountryService); check the digits
      // and separator rather than hardcoding the full "KES 32,000/mo"
      // string, so this doesn't churn if the currency prefix ever changes.
      expect(find.textContaining('32,000'), findsOneWidget);
      expect(find.text('Kilimani, Nairobi'), findsOneWidget);
    });

    testWidgets('shows Verified badge only when property.verified is true', (tester) async {
      await tester.pumpWidget(_wrap(PropertyCard(property: _property(verified: true))));
      expect(find.text('Verified'), findsOneWidget);

      await tester.pumpWidget(_wrap(PropertyCard(property: _property(verified: false))));
      expect(find.text('Verified'), findsNothing);
    });

    testWidgets('shows NEW badge for a listing posted within the last 7 days', (tester) async {
      final recent = DateTime.now().subtract(const Duration(days: 2)).toIso8601String();
      await tester.pumpWidget(_wrap(PropertyCard(property: _property(listedAt: recent))));
      expect(find.text('NEW'), findsOneWidget);
    });

    testWidgets('does not show NEW badge for an older listing', (tester) async {
      final old = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
      await tester.pumpWidget(_wrap(PropertyCard(property: _property(listedAt: old))));
      expect(find.text('NEW'), findsNothing);
    });

    testWidgets('shows Taken next to the title when the listing is unavailable', (tester) async {
      await tester.pumpWidget(_wrap(PropertyCard(property: _property(available: false))));
      expect(find.text('Taken'), findsOneWidget);
    });

    testWidgets('shows Worth checking badge when the property has risk flags', (tester) async {
      await tester.pumpWidget(_wrap(PropertyCard(property: _property(riskFlags: const ['unverified_photos']))));
      expect(find.text('Worth checking'), findsOneWidget);
    });

    testWidgets('pluralizes the bathroom count correctly', (tester) async {
      // Regression check: the pre-i18n copy always said "bath" even for
      // plural counts ("3 bath"). This is now real ICU plural logic.
      await tester.pumpWidget(_wrap(PropertyCard(property: _property(bathrooms: 1))));
      expect(find.text('1 bath'), findsOneWidget);

      await tester.pumpWidget(_wrap(PropertyCard(property: _property(bathrooms: 3))));
      expect(find.text('3 baths'), findsOneWidget);
    });
  });

  group('PropertyCard callback overrides', () {
    testWidgets('onTap override fires instead of default navigation', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(PropertyCard(
        property: _property(),
        onTap: () => tapped = true,
      )));

      await tester.tap(find.byType(PropertyCard));
      expect(tapped, isTrue);
    });

    testWidgets('onFavoriteTap override fires on favorite tap', (tester) async {
      var favorited = false;
      await tester.pumpWidget(_wrap(PropertyCard(
        property: _property(),
        onFavoriteTap: () => favorited = true,
      )));

      await tester.tap(find.byIcon(Icons.favorite_border));
      expect(favorited, isTrue);
    });

    testWidgets('onCall override fires instead of dialing', (tester) async {
      var called = false;
      await tester.pumpWidget(_wrap(PropertyCard(
        property: _property(),
        onCall: () => called = true,
      )));

      await tester.tap(find.byTooltip('Call'));
      expect(called, isTrue);
    });

    testWidgets('onChat override fires instead of navigating to chat', (tester) async {
      var chatted = false;
      await tester.pumpWidget(_wrap(PropertyCard(
        property: _property(),
        onChat: () => chatted = true,
      )));

      await tester.tap(find.byTooltip('Chat'));
      expect(chatted, isTrue);
    });

    testWidgets('onNavigate override fires instead of opening the map', (tester) async {
      var navigated = false;
      await tester.pumpWidget(_wrap(PropertyCard(
        property: _property(),
        onNavigate: () => navigated = true,
      )));

      await tester.tap(find.byTooltip('Navigate'));
      expect(navigated, isTrue);
    });
  });

  group('PropertyCard default navigation (no overrides)', () {
    testWidgets('tapping the card pushes a route', (tester) async {
      final observer = _RecordingNavigatorObserver();
      await tester.pumpWidget(_wrap(PropertyCard(property: _property()), observer: observer));

      await tester.tap(find.byType(PropertyCard));
      expect(observer.pushed, isNotEmpty);
    });

    testWidgets('Navigate pushes a route when onNavigate is not overridden', (tester) async {
      final observer = _RecordingNavigatorObserver();
      await tester.pumpWidget(_wrap(PropertyCard(property: _property()), observer: observer));

      await tester.tap(find.byTooltip('Navigate'));
      expect(observer.pushed, isNotEmpty);
    });

    testWidgets('Chat pushes a route when the property has a linked owner', (tester) async {
      final observer = _RecordingNavigatorObserver();
      final owner = User(id: 1, name: 'Jane Landlord', email: 'jane@example.com', role: 'LANDLORD');
      await tester.pumpWidget(_wrap(PropertyCard(property: _property(owner: owner)), observer: observer));

      await tester.tap(find.byTooltip('Chat'));
      expect(observer.pushed, isNotEmpty);
    });

    testWidgets('Chat shows a snackbar instead of navigating when there is no owner', (tester) async {
      await tester.pumpWidget(_wrap(PropertyCard(property: _property(owner: null))));

      await tester.tap(find.byTooltip('Chat'));
      await tester.pump(); // safe here: no page push happens on this path.

      expect(find.text('Landlord contact unavailable for chat'), findsOneWidget);
    });
  });

  group('PropertyCard Call (default dialer behavior)', () {
    late _FakeUrlLauncher fakeLauncher;
    final originalLauncher = UrlLauncherPlatform.instance;

    setUp(() {
      fakeLauncher = _FakeUrlLauncher();
      UrlLauncherPlatform.instance = fakeLauncher;
    });

    tearDown(() {
      UrlLauncherPlatform.instance = originalLauncher;
    });

    testWidgets('dials a sanitized tel: URI for a formatted phone number', (tester) async {
      // Regression check for the phone-sanitization fix: dashes/parens/
      // spaces used to produce an invalid tel: URI.
      await tester.pumpWidget(_wrap(PropertyCard(property: _property(landlordPhone: '+254 (712) 345-678'))));

      await tester.tap(find.byTooltip('Call'));
      await tester.pump();

      expect(fakeLauncher.launchedUrls, ['tel:+254712345678']);
    });

    testWidgets('shows a snackbar instead of dialing when there is no phone number', (tester) async {
      await tester.pumpWidget(_wrap(PropertyCard(property: _property(landlordPhone: ''))));

      await tester.tap(find.byTooltip('Call'));
      await tester.pump();

      expect(find.text('No phone number available for this listing'), findsOneWidget);
      expect(fakeLauncher.launchedUrls, isEmpty);
    });

    testWidgets('shows a snackbar when the dialer fails to open', (tester) async {
      // Regression check for the original bug: this used to fail
      // completely silently with no user feedback at all.
      fakeLauncher = _FakeUrlLauncher(succeeds: false);
      UrlLauncherPlatform.instance = fakeLauncher;
      await tester.pumpWidget(_wrap(PropertyCard(property: _property())));

      await tester.tap(find.byTooltip('Call'));
      await tester.pump();

      expect(find.text('Could not open the phone dialer'), findsOneWidget);
    });
  });

  group('PropertyCard accessibility', () {
    testWidgets('favorite button semantics label toggles with isFavorite', (tester) async {
      // Disposed in the body, not addTearDown: flutter_test verifies no
      // semantics handle is outstanding before teardown callbacks run.
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_wrap(PropertyCard(property: _property(), isFavorite: false)));
      expect(find.bySemanticsLabel('Add to favorites'), findsOneWidget);

      await tester.pumpWidget(_wrap(PropertyCard(property: _property(), isFavorite: true)));
      expect(find.bySemanticsLabel('Remove from favorites'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('the card exposes one button-role semantics summary including the title', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_wrap(PropertyCard(property: _property(title: 'Riverside Studio'))));
      expect(find.bySemanticsLabel(RegExp('Riverside Studio')), findsOneWidget);

      handle.dispose();
    });
  });

  group('PropertyCard regression: stale gallery cache (bug fix)', () {
    testWidgets('didUpdateWidget refreshes the gallery when bound to a different Property', (tester) async {
      const cardKey = ValueKey('card-under-test');
      final propertyA = _property(id: 1, imageUrl: 'https://example.com/a.jpg');
      final propertyB = _property(id: 1, imageUrl: 'https://example.com/b.jpg');

      await tester.pumpWidget(_wrap(PropertyCard(key: cardKey, property: propertyA)));
      expect(
        tester.widget<PropertyImage>(find.byType(PropertyImage)).imageUrls,
        ['https://example.com/a.jpg'],
      );

      // Same key -> same State object reused, simulating exactly the list
      // element-reuse scenario the fix targets. Before the fix, this
      // would still show propertyA's image here.
      await tester.pumpWidget(_wrap(PropertyCard(key: cardKey, property: propertyB)));
      expect(
        tester.widget<PropertyImage>(find.byType(PropertyImage)).imageUrls,
        ['https://example.com/b.jpg'],
      );
    });

    testWidgets('does not rebuild the gallery list when images are unchanged', (tester) async {
      const cardKey = ValueKey('card-under-test');
      final propertyA = _property(id: 1, imageUrl: 'https://example.com/a.jpg', title: 'Version A');
      final propertyB = _property(id: 1, imageUrl: 'https://example.com/a.jpg', title: 'Version B');

      await tester.pumpWidget(_wrap(PropertyCard(key: cardKey, property: propertyA)));
      final firstGallery = tester.widget<PropertyImage>(find.byType(PropertyImage)).imageUrls;

      await tester.pumpWidget(_wrap(PropertyCard(key: cardKey, property: propertyB)));
      final secondGallery = tester.widget<PropertyImage>(find.byType(PropertyImage)).imageUrls;

      expect(identical(firstGallery, secondGallery), isTrue);
    });
  });
}
