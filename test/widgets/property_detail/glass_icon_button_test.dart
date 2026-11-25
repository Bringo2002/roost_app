import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/widgets/property_detail/glass_icon_button.dart';

Widget _wrap(GlassIconButton button) {
  return MaterialApp(home: Scaffold(body: Center(child: button)));
}

void main() {
  group('GlassIconButton', () {
    testWidgets('calls onTap once per tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(GlassIconButton(icon: Icons.share_outlined, onTap: () => taps++)));

      await tester.tap(find.byType(IconButton));

      expect(taps, 1);
    });

    testWidgets('draws its icon in white by default', (tester) async {
      await tester.pumpWidget(_wrap(GlassIconButton(icon: Icons.share_outlined, onTap: () {})));

      expect(tester.widget<Icon>(find.byIcon(Icons.share_outlined)).color, AppColors.white);
    });

    testWidgets('uses the given colour for its icon', (tester) async {
      await tester.pumpWidget(
        _wrap(GlassIconButton(icon: Icons.share_outlined, color: AppColors.favoriteActive, onTap: () {})),
      );

      expect(tester.widget<Icon>(find.byIcon(Icons.share_outlined)).color, AppColors.favoriteActive);
    });

    testWidgets('is 44x44, the minimum comfortable touch target', (tester) async {
      await tester.pumpWidget(_wrap(GlassIconButton(icon: Icons.share_outlined, onTap: () {})));

      expect(tester.getSize(find.byType(GlassIconButton)), const Size(44, 44));
    });

    testWidgets('keeps its full 44px in the 56px-wide app bar slot with the padding the page uses', (tester) async {
      // Mirrors PropertyDetailPage's `leading`: AppBar gives `leading` a 56px
      // wide slot, so any more than 6 of padding per side shrinks the button.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              leading: Padding(
                padding: const EdgeInsets.all(6),
                child: GlassIconButton(icon: Icons.arrow_back, onTap: () {}),
              ),
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(GlassIconButton)), const Size(44, 44));
    });

    testWidgets('exposes the tooltip, which is also the label a screen reader announces', (tester) async {
      await tester.pumpWidget(_wrap(GlassIconButton(icon: Icons.share_outlined, tooltip: 'Share', onTap: () {})));

      expect(find.byTooltip('Share'), findsOneWidget);
    });

    testWidgets('has no tooltip when none is given', (tester) async {
      await tester.pumpWidget(_wrap(GlassIconButton(icon: Icons.share_outlined, onTap: () {})));

      expect(find.byType(Tooltip), findsNothing);
    });

    testWidgets('a custom child replaces the icon entirely', (tester) async {
      await tester.pumpWidget(
        _wrap(GlassIconButton(icon: Icons.favorite_border, onTap: () {}, child: const Text('custom'))),
      );

      expect(find.text('custom'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsNothing);
    });
  });
}
