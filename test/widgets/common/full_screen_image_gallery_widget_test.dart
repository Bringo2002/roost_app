import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roost_app/l10n/generated/app_localizations.dart';
import 'package:roost_app/widgets/common/full_screen_image_gallery.dart';

import '../../helpers/offline_images.dart';

const _urls = [
  'https://example.test/photo-a.jpg',
  'https://example.test/photo-b.jpg',
  'https://example.test/photo-c.jpg',
];

/// Counts how many times a route was popped off the navigator.
class _PopCounter extends NavigatorObserver {
  int pops = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => pops++;
}

/// What the open viewer reported to its caller.
class _Harness {
  final observer = _PopCounter();
  final changedPhotos = <int>[];

  int get pops => observer.pops;
}

/// Pumps an app with an "open" button, taps it, and settles on the viewer.
///
/// [reduceMotion] sets the OS "remove animations" flag the viewer reads via
/// `MediaQuery.disableAnimationsOf`.
Future<_Harness> _openViewer(WidgetTester tester, {bool reduceMotion = false}) async {
  final harness = _Harness();
  await tester.pumpWidget(
    MaterialApp(
      navigatorObservers: [harness.observer],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion), child: child!),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => FullScreenImageGallery.open(context, _urls, onPhotoChanged: harness.changedPhotos.add),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return harness;
}

void main() {
  setUp(useOfflineImages);

  group('FullScreenImageGallery', () {
    testWidgets('opens on the first photo with its chrome', (tester) async {
      await _openViewer(tester);

      expect(find.byType(FullScreenImageGallery), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
      // The offline cache manager fails every load, so the viewer's own
      // error state is what is on screen.
      expect(find.text('Could not load image'), findsWidgets);
    });

    testWidgets('swiping to the next photo updates the counter and reports the new index', (tester) async {
      final harness = await _openViewer(tester);

      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('2 / 3'), findsOneWidget);
      expect(harness.changedPhotos, [1]);
    });
  });
}
