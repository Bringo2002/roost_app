import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roost_app/l10n/generated/app_localizations.dart';
import 'package:roost_app/widgets/property_detail/map_preview_tap_target.dart';

Widget _host(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: SizedBox(width: 300, height: 200, child: child))),
  );
}

void main() {
  group('MapPreviewTapTarget', () {
    testWidgets('is a button that says what the map shows and what activating it does', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var opened = 0;
      await tester.pumpWidget(_host(MapPreviewTapTarget(onTap: () => opened++)));

      expect(
        tester.getSemantics(find.bySemanticsLabel('Map showing where this property is')),
        containsSemantics(
          label: 'Map showing where this property is',
          hint: 'Opens the full-screen map',
          isButton: true,
          hasTapAction: true,
        ),
      );

      tester.semantics.tap(find.semantics.byLabel('Map showing where this property is'));
      expect(opened, 1);
      handle.dispose();
    });

    testWidgets('a real tap opens the map too', (tester) async {
      var opened = 0;
      await tester.pumpWidget(_host(MapPreviewTapTarget(onTap: () => opened++)));

      await tester.tap(find.byType(InkWell));
      expect(opened, 1);
    });

    testWidgets('is localized to Swahili', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(MapPreviewTapTarget(onTap: () {}), locale: const Locale('sw')),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Ramani inayoonyesha mali hii ilipo')),
        containsSemantics(hint: 'Hufungua ramani kwenye skrini nzima', isButton: true),
      );
      handle.dispose();
    });
  });
}
