import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/theme/app_theme.dart';
import 'package:roost_app/widgets/common/roost_search_bar.dart';

Widget _host({
  required TextEditingController controller,
  required FocusNode focusNode,
  VoidCallback? onClear,
  Widget? below,
}) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    home: Scaffold(
      body: Column(
        children: [
          RoostSearchBar(
            controller: controller,
            focusNode: focusNode,
            hintText: 'Search',
            onClear: onClear,
          ),
          if (below != null) below,
        ],
      ),
    ),
  );
}

Color _borderColor(WidgetTester tester) {
  final container = tester.widget<AnimatedContainer>(
    find.descendant(
      of: find.byType(RoostSearchBar),
      matching: find.byType(AnimatedContainer),
    ).first,
  );
  final decoration = container.decoration! as BoxDecoration;
  return (decoration.border! as Border).top.color;
}

void main() {
  late TextEditingController controller;
  late FocusNode focusNode;

  setUp(() {
    controller = TextEditingController();
    focusNode = FocusNode();
  });

  tearDown(() {
    controller.dispose();
    focusNode.dispose();
  });

  testWidgets('clear button is hidden when empty and shown when there is text', (tester) async {
    await tester.pumpWidget(_host(controller: controller, focusNode: focusNode));
    expect(find.byTooltip('Clear search'), findsNothing);

    controller.text = 'kutus';
    await tester.pump();
    expect(find.byTooltip('Clear search'), findsOneWidget);
  });

  testWidgets('tapping clear empties the field, fires onClear and keeps focus', (tester) async {
    var cleared = 0;
    await tester.pumpWidget(_host(
      controller: controller,
      focusNode: focusNode,
      onClear: () => cleared++,
    ));

    await tester.tap(find.byType(TextField));
    await tester.pump();
    controller.text = 'kutus';
    await tester.pump();

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();

    expect(controller.text, isEmpty);
    expect(cleared, 1);
    expect(focusNode.hasFocus, isTrue);
  });

  testWidgets('focus changes the border colour without changing its width', (tester) async {
    await tester.pumpWidget(_host(controller: controller, focusNode: focusNode));
    final unfocused = _borderColor(tester);
    expect(unfocused, AppColors.border);

    focusNode.requestFocus();
    await tester.pump();
    expect(_borderColor(tester), isNot(unfocused));

    final container = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(RoostSearchBar),
        matching: find.byType(AnimatedContainer),
      ).first,
    );
    final border = (container.decoration! as BoxDecoration).border! as Border;
    expect(border.top.width, 1);
  });

  testWidgets('follows the FocusNode when the parent swaps it', (tester) async {
    final other = FocusNode();
    addTearDown(other.dispose);

    await tester.pumpWidget(_host(controller: controller, focusNode: focusNode));
    await tester.pumpWidget(_host(controller: controller, focusNode: other));

    other.requestFocus();
    await tester.pump();
    expect(_borderColor(tester), isNot(AppColors.border));

    // The old node must no longer drive the visuals.
    other.unfocus();
    await tester.pump();
    focusNode.requestFocus();
    await tester.pump();
    expect(_borderColor(tester), AppColors.border);
  });

  testWidgets('tapping outside dismisses focus', (tester) async {
    await tester.pumpWidget(_host(
      controller: controller,
      focusNode: focusNode,
      below: const SizedBox(key: Key('outside'), height: 200, width: 200),
    ));

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.tap(find.byKey(const Key('outside')));
    await tester.pump();
    expect(focusNode.hasFocus, isFalse);
  });

  testWidgets('grows instead of clipping at large text scale', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(3)),
          child: Scaffold(
            body: RoostSearchBar(
              controller: controller,
              focusNode: focusNode,
              hintText: 'Search',
            ),
          ),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    final size = tester.getSize(
      find.descendant(
        of: find.byType(RoostSearchBar),
        matching: find.byType(AnimatedContainer),
      ).first,
    );
    expect(size.height, greaterThanOrEqualTo(48));
  });
}
