import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/widgets/profile/deletion_scheduled_banner.dart';

void main() {
  // A local time, so the conversion to local is a no-op on any machine.
  final scheduledAt = DateTime(2026, 12, 5, 12);

  Widget wrap({bool cancelling = false, VoidCallback? onCancel}) {
    return MaterialApp(
      home: Scaffold(
        body: DeletionScheduledBanner(
          scheduledAt: scheduledAt,
          cancelling: cancelling,
          onCancel: onCancel ?? () {},
        ),
      ),
    );
  }

  testWidgets('says when the account will be deleted', (tester) async {
    await tester.pumpWidget(wrap());

    expect(find.text('Account deletion scheduled'), findsOneWidget);
    expect(find.textContaining('5 December 2026'), findsOneWidget);
  });

  testWidgets('tapping Cancel deletion calls onCancel', (tester) async {
    var taps = 0;
    await tester.pumpWidget(wrap(onCancel: () => taps++));

    await tester.tap(find.byKey(const Key('cancel-deletion-button')));

    expect(taps, 1);
  });

  testWidgets('while cancelling, the button is disabled and shows progress', (tester) async {
    var taps = 0;
    await tester.pumpWidget(wrap(cancelling: true, onCancel: () => taps++));

    final button = tester.widget<OutlinedButton>(find.byKey(const Key('cancel-deletion-button')));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Cancel deletion'), findsNothing);

    await tester.tap(find.byKey(const Key('cancel-deletion-button')), warnIfMissed: false);
    expect(taps, 0);
  });
}
