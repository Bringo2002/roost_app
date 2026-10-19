import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roost_app/l10n/generated/app_localizations.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/widgets/property_detail/property_bottom_bar.dart';

Property _property() {
  return Property(
    id: 1,
    title: 'Modern Apartments',
    description: 'A lovely place to call home.',
    location: 'Kilimani, Nairobi',
    price: 60000,
    bedrooms: 2,
    type: 'RENTAL',
    landlordPhone: '+254712345678',
    available: true,
  );
}

Widget _host(Widget bar, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(bottomNavigationBar: bar),
  );
}

void main() {
  group('PropertyBottomBar semantics', () {
    testWidgets('the icon-only call button is a named button that activates via semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var calls = 0;
      await tester.pumpWidget(
        _host(PropertyBottomBar(property: _property(), onCall: () => calls++, onChat: () {})),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Call host')),
        containsSemantics(label: 'Call host', isButton: true, hasTapAction: true),
      );

      tester.semantics.tap(find.semantics.byLabel('Call host'));
      expect(calls, 1);
      handle.dispose();
    });

    testWidgets('the chat button is a button named after its visible text', (tester) async {
      final handle = tester.ensureSemantics();
      var chats = 0;
      await tester.pumpWidget(
        _host(PropertyBottomBar(property: _property(), onCall: () {}, onChat: () => chats++)),
      );

      expect(find.text('Chat with host'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Chat with host')),
        containsSemantics(label: 'Chat with host', isButton: true, hasTapAction: true),
      );

      tester.semantics.tap(find.semantics.byLabel('Chat with host'));
      expect(chats, 1);
      handle.dispose();
    });

    testWidgets('a real tap still triggers the callbacks', (tester) async {
      var calls = 0;
      var chats = 0;
      await tester.pumpWidget(
        _host(PropertyBottomBar(property: _property(), onCall: () => calls++, onChat: () => chats++)),
      );

      await tester.tap(find.byIcon(Icons.phone_outlined));
      await tester.tap(find.text('Chat with host'));
      expect(calls, 1);
      expect(chats, 1);
    });

    testWidgets('both buttons are localized to Swahili', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          PropertyBottomBar(property: _property(), onCall: () {}, onChat: () {}),
          locale: const Locale('sw'),
        ),
      );

      expect(find.bySemanticsLabel('Piga simu kwa mwenyeji'), findsOneWidget);
      expect(find.bySemanticsLabel('Ongea na mwenyeji'), findsOneWidget);
      expect(find.text('Ongea na mwenyeji'), findsOneWidget);
      handle.dispose();
    });
  });
}
