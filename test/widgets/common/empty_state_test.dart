import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/widgets/common/empty_state.dart';

void main() {
  group('EmptyStateWidget', () {
    testWidgets('action button uses the monochrome white accent', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              title: 'Nothing here',
              subtitle: 'Try again',
              buttonText: 'Retry',
              onButtonPressed: () {},
            ),
          ),
        ),
      );

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      final bg = button.style?.backgroundColor?.resolve(<WidgetState>{});
      expect(bg, AppColors.white);
    });

    testWidgets('tapping the action button invokes the callback', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              title: 'Nothing here',
              subtitle: 'Try again',
              buttonText: 'Retry',
              onButtonPressed: () => taps++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Retry'));
      expect(taps, 1);
    });

    testWidgets('omits the button when no action is provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(title: 'Nothing here', subtitle: 'Try again'),
          ),
        ),
      );

      expect(find.byType(ElevatedButton), findsNothing);
    });
  });
}
