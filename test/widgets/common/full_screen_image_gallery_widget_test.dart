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
/// `MediaQuery.disableAnimationsOf`. [heroTagFor] is passed through to the viewer.
Future<_Harness> _openViewer(
  WidgetTester tester, {
  bool reduceMotion = false,
  Object Function(int index)? heroTagFor,
}) async {
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
              onPressed: () => FullScreenImageGallery.open(
                context,
                _urls,
                onPhotoChanged: harness.changedPhotos.add,
                heroTagFor: heroTagFor,
              ),
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

/// The tags of every [Hero] currently built.
Set<Object> _heroTags(WidgetTester tester) =>
    tester.widgetList<Hero>(find.byType(Hero)).map((hero) => hero.tag).toSet();

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

    testWidgets('the close button pops the viewer exactly once', (tester) async {
      final harness = await _openViewer(tester);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(harness.pops, 1);
      expect(find.byType(FullScreenImageGallery), findsNothing);
    });
  });

  group('FullScreenImageGallery drag to dismiss', () {
    testWidgets('a long drag down carries the photo away, then pops once', (tester) async {
      final harness = await _openViewer(tester);

      await tester.drag(find.byType(PageView), const Offset(0, 300));

      // The exit animation has not run yet; the route is popped only after it.
      expect(harness.pops, 0);

      await tester.pumpAndSettle();

      expect(harness.pops, 1);
      expect(find.byType(FullScreenImageGallery), findsNothing);
    });

    testWidgets('a short, slow drag snaps back to rest without popping', (tester) async {
      final harness = await _openViewer(tester);

      // 60px over a full second: well under the distance threshold, and far
      // below the fling velocity that would dismiss on its own.
      await tester.timedDrag(find.byType(PageView), const Offset(0, 60), const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(harness.pops, 0);
      expect(find.byType(FullScreenImageGallery), findsOneWidget);
      expect(tester.getTopLeft(find.byType(PageView)), Offset.zero);
    });

    testWidgets('with reduced motion the drag pops immediately, without an exit animation', (tester) async {
      final harness = await _openViewer(tester, reduceMotion: true);

      await tester.drag(find.byType(PageView), const Offset(0, 300));

      expect(harness.pops, 1);

      await tester.pumpAndSettle();

      expect(find.byType(FullScreenImageGallery), findsNothing);
    });
  });

  group('FullScreenImageGallery hero', () {
    testWidgets('wraps the photo in a Hero with the caller\'s tag', (tester) async {
      await _openViewer(tester, heroTagFor: (index) => 'photo-$index');

      expect(_heroTags(tester), contains('photo-0'));
    });

    testWidgets('the photo shown after a swipe carries its own tag', (tester) async {
      await _openViewer(tester, heroTagFor: (index) => 'photo-$index');

      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();

      expect(_heroTags(tester), contains('photo-1'));
    });

    testWidgets('builds no Hero when the caller gives no tags', (tester) async {
      await _openViewer(tester);

      expect(find.byType(Hero), findsNothing);
    });
  });
}
