import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roost_app/l10n/generated/app_localizations.dart';
import 'package:roost_app/widgets/property_detail/roost_bottom_sheet.dart';

Widget _host(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}

Widget _radioList({
  required String selected,
  ValueChanged<String>? onChanged,
  bool enabled = true,
}) {
  return _host(
    SizedBox(
      width: 360,
      child: RoostRadioList<String>(
        options: const ['Fake listing', 'Other'],
        labelOf: (option) => option,
        selected: selected,
        onChanged: onChanged ?? (_) {},
        enabled: enabled,
      ),
    ),
  );
}

void main() {
  group('RoostRadioList semantics', () {
    testWidgets('the selected option is checked and every option shares one radio group', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_radioList(selected: 'Fake listing'));

      expect(
        tester.getSemantics(find.bySemanticsLabel('Fake listing')),
        containsSemantics(
          label: 'Fake listing',
          isInMutuallyExclusiveGroup: true,
          hasCheckedState: true,
          isChecked: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Other')),
        containsSemantics(
          label: 'Other',
          isInMutuallyExclusiveGroup: true,
          hasCheckedState: true,
          isChecked: false,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('activating an option through semantics selects it', (tester) async {
      final handle = tester.ensureSemantics();
      String? picked;
      await tester.pumpWidget(_radioList(selected: 'Fake listing', onChanged: (v) => picked = v));

      tester.semantics.tap(find.semantics.byLabel('Other'));
      expect(picked, 'Other');
      handle.dispose();
    });

    testWidgets('a real tap still selects an option', (tester) async {
      String? picked;
      await tester.pumpWidget(_radioList(selected: 'Fake listing', onChanged: (v) => picked = v));

      await tester.tap(find.text('Other'));
      expect(picked, 'Other');
    });

    testWidgets('when disabled, options are announced as disabled and cannot be activated', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_radioList(selected: 'Fake listing', enabled: false));

      expect(
        tester.getSemantics(find.bySemanticsLabel('Other')),
        containsSemantics(hasEnabledState: true, isEnabled: false, hasTapAction: false),
      );
      handle.dispose();
    });
  });

  group('RoostSheetSubmitButton semantics', () {
    testWidgets('keeps its own label when idle', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          RoostSheetSubmitButton(label: 'Submit Report', onPressed: () {}, isSubmitting: false),
        ),
      );

      expect(find.bySemanticsLabel('Submit Report'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('keeps a name and announces the busy state while submitting', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          RoostSheetSubmitButton(label: 'Submit Report', onPressed: () {}, isSubmitting: true),
        ),
      );

      // The spinner replaces the visible label, so the name has to come from it.
      expect(find.text('Submit Report'), findsNothing);
      expect(find.bySemanticsLabel(RegExp(r'Submit Report, submitting')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the busy label is localized to Swahili', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          RoostSheetSubmitButton(label: 'Submit Report', onPressed: () {}, isSubmitting: true),
          locale: const Locale('sw'),
        ),
      );

      expect(find.bySemanticsLabel(RegExp(r'Submit Report, inatuma')), findsOneWidget);
      handle.dispose();
    });
  });

  group('RoostBottomSheet semantics', () {
    testWidgets('exposes the sheet title as a heading', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => RoostBottomSheet.show(
                context: context,
                title: 'Report Listing',
                subtitle: 'Why are you reporting this property?',
                builder: (_) => const SizedBox.shrink(),
              ),
              child: const Text('Open sheet'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open sheet'));
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.bySemanticsLabel('Report Listing')),
        containsSemantics(label: 'Report Listing', isHeader: true),
      );
      handle.dispose();
    });
  });
}
