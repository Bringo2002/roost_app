import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/models/report_reason.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/widgets/chat/report_user_sheet.dart';

void main() {
  /// A tall surface so the whole sheet is on screen without scrolling.
  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// Opens the sheet from a button and returns what [ReportUserSheet.show]
  /// completes with once the sheet is dismissed.
  Future<void> openSheet(
    WidgetTester tester, {
    required Future<void> Function(ReportReason, String?) onSubmit,
    required List<bool?> results,
  }) async {
    useTallScreen(tester);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                results.add(await ReportUserSheet.show(
                  context,
                  userName: 'Ada',
                  onSubmit: onSubmit,
                ));
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  final submitButton = find.byKey(const Key('report-submit-button'));

  bool submitEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(submitButton).onPressed != null;

  testWidgets('names the person and lists every reason', (tester) async {
    await openSheet(tester, onSubmit: (_, __) async {}, results: []);

    expect(find.text('Report Ada'), findsOneWidget);
    for (final reason in ReportReason.values) {
      expect(find.text(reason.label), findsOneWidget);
    }
  });

  testWidgets('cannot be sent until a reason is chosen', (tester) async {
    await openSheet(tester, onSubmit: (_, __) async {}, results: []);

    expect(submitEnabled(tester), isFalse);

    await tester.tap(find.text('Spam'));
    await tester.pump();

    expect(submitEnabled(tester), isTrue);
  });

  testWidgets('sends the reason and the note, then closes with true', (tester) async {
    final sent = <(ReportReason, String?)>[];
    final results = <bool?>[];
    await openSheet(
      tester,
      onSubmit: (reason, note) async => sent.add((reason, note)),
      results: results,
    );

    await tester.tap(find.text('Harassment or abuse'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '  keeps insulting me  ');
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(sent, [(ReportReason.harassment, 'keeps insulting me')]);
    expect(find.byType(ReportUserSheet), findsNothing);
    expect(results, [true]);
  });

  testWidgets('sends no note when the note is left blank', (tester) async {
    final sent = <(ReportReason, String?)>[];
    await openSheet(
      tester,
      onSubmit: (reason, note) async => sent.add((reason, note)),
      results: [],
    );

    await tester.tap(find.text('Scam or fraud'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(sent, [(ReportReason.scamOrFraud, null)]);
  });

  testWidgets('limits the note to what the backend accepts', (tester) async {
    await openSheet(tester, onSubmit: (_, __) async {}, results: []);

    expect(tester.widget<TextField>(find.byType(TextField)).maxLength, kMaxReportNoteLength);
  });

  testWidgets('stays open and shows the reason when sending fails', (tester) async {
    final results = <bool?>[];
    await openSheet(
      tester,
      onSubmit: (_, __) async => throw ApiException(
        "You've already reported this user. Our team will review it.",
        statusCode: 409,
      ),
      results: results,
    );

    await tester.tap(find.text('Spam'));
    await tester.pump();
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(find.text("You've already reported this user. Our team will review it."), findsOneWidget);
    expect(find.byType(ReportUserSheet), findsOneWidget);
    expect(submitEnabled(tester), isTrue);
    expect(results, isEmpty);
  });

  testWidgets('cancel closes the sheet without sending', (tester) async {
    final sent = <ReportReason>[];
    final results = <bool?>[];
    await openSheet(tester, onSubmit: (reason, _) async => sent.add(reason), results: results);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(ReportUserSheet), findsNothing);
    expect(sent, isEmpty);
    expect(results, [false]);
  });
}
