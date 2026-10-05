import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:roost_app/l10n/generated/app_localizations.dart';
import 'package:roost_app/pages/profile/saved_page.dart';
import 'package:roost_app/services/api_service.dart';

/// SavedPageState._loadSaved runs unconditionally in initState, before
/// any test gets a chance to pump a frame -- so every test here has to
/// get past AuthService.getToken() (FlutterSecureStorage, then a
/// SharedPreferences fallback) and FavoritesService.getSavedProperties
/// (a real HTTP GET) before anything else can be asserted. Relies on
/// FlutterSecureStorage's own setMockInitialValues test helper rather
/// than guessing its platform channel name.
///
/// HTTP is stubbed by assigning ApiService.client (the same seam the
/// landlord dashboard tests use) and resetting it in tearDown.
/// http.runWithClient is deliberately not used: ApiService.client is a
/// static that is created once, so whichever test touched it first would
/// pin its client for every later test in the file.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() {
    // Don't let one test's stub leak into the next.
    ApiService.client = http.Client();
  });

  Map<String, dynamic> propertyJson({
    required int id,
    required String title,
    double price = 25000,
    String location = 'Kilimani, Nairobi',
  }) {
    return {
      'id': id,
      'title': title,
      'description': 'A lovely place to call home.',
      'location': location,
      'price': price,
      'bedrooms': 1,
      'bathrooms': 1,
      'available': true,
      'landlordPhone': '+254712345678',
    };
  }

  Widget wrap() {
    return const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SavedPage(),
    );
  }

  /// Routes every request by path suffix rather than the full URL, so
  /// these tests don't also need to hardcode AppConfig.baseUrl.
  MockClient clientReturning({
    List<Map<String, dynamic>> saved = const [],
    List<String> deletedCalls = const [],
  }) {
    return MockClient((request) async {
      if (request.method == 'GET' && request.url.path.endsWith('/api/properties/saved')) {
        return http.Response(jsonEncode(saved), 200);
      }
      if (request.method == 'DELETE' && request.url.path.contains('/save')) {
        deletedCalls.add(request.url.path);
        return http.Response('', 204);
      }
      if (request.method == 'POST' && request.url.path.contains('/save')) {
        return http.Response('', 200);
      }
      return http.Response('Not found', 404);
    });
  }

  group('SavedPage empty state', () {
    testWidgets('shows the empty-state message and CTA when nothing is saved', (tester) async {
      ApiService.client = clientReturning();
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('No Saved Properties'), findsOneWidget);
      expect(find.text('Explore Properties'), findsOneWidget);
    });
  });

  group('SavedPage with saved properties', () {
    testWidgets('renders a PropertyCard per saved property', (tester) async {
      ApiService.client = clientReturning(saved: [propertyJson(id: 1, title: 'Sunset Apartments')]);
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Sunset Apartments'), findsOneWidget);
      expect(find.text('No Saved Properties'), findsNothing);
    });

    testWidgets('tapping the favorite (heart) icon removes the property and shows an Undo snackbar', (tester) async {
      final deletedCalls = <String>[];
      ApiService.client = clientReturning(
        saved: [propertyJson(id: 1, title: 'Sunset Apartments')],
        deletedCalls: deletedCalls,
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Sunset Apartments'), findsOneWidget);

      // PropertyCard's favorite button carries its own semantic
      // label independent of the card's -- see property_card_test.dart.
      await tester.tap(find.bySemanticsLabel('Remove from favorites'));
      await tester.pumpAndSettle();

      expect(find.text('Sunset Apartments'), findsNothing);
      expect(find.textContaining('removed from saved'), findsOneWidget);
      expect(find.text('UNDO'), findsOneWidget);
      expect(deletedCalls, isNotEmpty);
    });
  });

  group('SavedSortOption', () {
    test('has the three expected options with non-empty labels and distinct icons', () {
      expect(SavedSortOption.values, hasLength(3));
      expect(SavedSortOption.values.map((o) => o.label).toSet(), hasLength(3));
      expect(SavedSortOption.values.map((o) => o.icon).toSet(), hasLength(3));
      expect(SavedSortOption.recent.label, 'All Saved');
      expect(SavedSortOption.priceLow.label, 'Price: Low to High');
      expect(SavedSortOption.priceHigh.label, 'Price: High to Low');
    });
  });
}
