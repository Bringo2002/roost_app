import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roost_app/l10n/generated/app_localizations.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/widgets/common/full_screen_image_gallery.dart';
import 'package:roost_app/widgets/property_detail/hero_media_gallery.dart';

import '../../helpers/offline_images.dart';

const _photoA = 'https://example.test/photo-a.jpg';
const _photoB = 'https://example.test/photo-b.jpg';
const _photoC = 'https://example.test/photo-c.jpg';

Property _property({
  int? id = 1,
  String? imageUrl,
  List<String> imageUrls = const [],
  String? videoUrl,
}) {
  return Property(
    id: id,
    title: 'Cozy Bedsitter',
    description: 'A lovely place to call home.',
    location: 'Kilimani, Nairobi',
    price: 25000,
    bedrooms: 1,
    type: 'RENTAL',
    landlordPhone: '+254712345678',
    available: true,
    imageUrl: imageUrl,
    imageUrls: imageUrls,
    videoUrl: videoUrl,
  );
}

/// Pumps the gallery at its real height and settles, so every offline photo
/// has already fallen back to its error placeholder.
Future<void> _pumpGallery(WidgetTester tester, Property property) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(height: kHeroMediaHeight, child: HeroMediaGallery(property: property)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Swipes the pager under [pager] one slide forward and settles.
Future<void> _swipeToNext(WidgetTester tester, Finder pager) async {
  await tester.fling(pager, const Offset(-300, 0), 1000);
  await tester.pumpAndSettle();
}

/// The photo viewer's own pager, as opposed to the gallery's underneath it.
Finder _viewerPager() =>
    find.descendant(of: find.byType(FullScreenImageGallery), matching: find.byType(PageView));

void main() {
  setUp(useOfflineImages);

  group('HeroMediaGallery slides', () {
    testWidgets('counts each distinct photo once, even when the primary image repeats in the list', (tester) async {
      await _pumpGallery(tester, _property(imageUrl: _photoA, imageUrls: [_photoA, _photoB, _photoC]));

      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('the video takes the first slide and the photos follow it', (tester) async {
      await _pumpGallery(
        tester,
        _property(imageUrls: [_photoA, _photoB], videoUrl: 'https://example.test/tour.mp4'),
      );

      expect(find.text('1 / 3'), findsOneWidget);
      // No video backend exists in a widget test, so the slide shows the
      // video's own failure state.
      expect(find.byIcon(Icons.videocam_off_outlined), findsOneWidget);
    });

    testWidgets('shows a placeholder and no pager when the listing has no media', (tester) async {
      await _pumpGallery(tester, _property());

      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
      expect(find.byType(PageView), findsNothing);
    });

    testWidgets('shows no counter for a single photo', (tester) async {
      await _pumpGallery(tester, _property(imageUrls: [_photoA]));

      expect(find.byType(PageView), findsOneWidget);
      expect(find.textContaining(' / '), findsNothing);
    });
  });

  group('HeroMediaGallery accessibility', () {
    testWidgets('a photo slide is a labelled button that says it opens the photo full screen', (tester) async {
      // Disposed in the body, not addTearDown: flutter_test verifies no
      // semantics handle is outstanding before teardown callbacks run.
      final handle = tester.ensureSemantics();

      await _pumpGallery(tester, _property(imageUrls: [_photoA, _photoB, _photoC]));

      expect(
        tester.getSemantics(find.bySemanticsLabel('Photo 1 of 3')),
        isSemantics(
          label: 'Photo 1 of 3',
          hint: 'Opens the photo full screen',
          isButton: true,
          isImage: true,
          hasTapAction: true,
        ),
      );

      handle.dispose();
    });
  });

  group('HeroMediaGallery and the full-screen viewer', () {
    testWidgets('tapping a photo opens the viewer on that photo', (tester) async {
      await _pumpGallery(tester, _property(imageUrls: [_photoA, _photoB, _photoC]));
      await _swipeToNext(tester, find.byType(PageView));

      await tester.tap(find.byType(PageView));
      await tester.pumpAndSettle();

      expect(find.byType(FullScreenImageGallery), findsOneWidget);
      expect(find.descendant(of: find.byType(FullScreenImageGallery), matching: find.text('2 / 3')), findsOneWidget);
    });

    testWidgets('closing the viewer leaves the gallery on the photo the viewer ended on', (tester) async {
      await _pumpGallery(tester, _property(imageUrls: [_photoA, _photoB, _photoC]));

      await tester.tap(find.byType(PageView));
      await tester.pumpAndSettle();
      await _swipeToNext(tester, _viewerPager());
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(find.byType(FullScreenImageGallery), findsNothing);
      expect(find.text('2 / 3'), findsOneWidget);
    });

    testWidgets('with a video in slide 0, the gallery follows the viewer to the matching photo slide', (tester) async {
      await _pumpGallery(
        tester,
        _property(imageUrls: [_photoA, _photoB, _photoC], videoUrl: 'https://example.test/tour.mp4'),
      );
      // Slide 0 is the video; slide 1 is the first photo.
      await _swipeToNext(tester, find.byType(PageView));
      expect(find.text('2 / 4'), findsOneWidget);

      await tester.tap(find.byType(PageView));
      await tester.pumpAndSettle();
      // The viewer counts photos only, so it opens on photo 1 of 3.
      expect(find.descendant(of: find.byType(FullScreenImageGallery), matching: find.text('1 / 3')), findsOneWidget);

      await _swipeToNext(tester, _viewerPager());
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      // Photo 2 of 3 sits on slide 3 of 4, behind the video.
      expect(find.byType(FullScreenImageGallery), findsNothing);
      expect(find.text('3 / 4'), findsOneWidget);
    });
  });
}
