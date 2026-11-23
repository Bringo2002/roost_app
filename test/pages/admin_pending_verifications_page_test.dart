import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:roost_app/l10n/generated/app_localizations.dart';
import 'package:roost_app/pages/admin/admin_pending_verifications_page.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/auth_service.dart';
import 'package:roost_app/widgets/common/full_screen_image_gallery.dart';

import '../helpers/offline_images.dart';

/// The pending-verifications queue and its audit sheet. HTTP is stubbed
/// through [ApiService.client] and the token through
/// [AuthService.getTokenOverride]; both are process-wide statics, so they are
/// reset in tearDown.
///
/// Most properties carry no document or photo URLs, so those tiles stay out
/// of the way. The photo-viewer tests give one property photos and install
/// [useOfflineImages], which fails every image load without the platform
/// plugins a widget test does not have. That leaves the documents caption
/// untested here.
void main() {
  late List<http.Request> posts;

  setUp(() {
    posts = [];
    AuthService.getTokenOverride = () async => 'test-token';
    useOfflineImages();
  });

  tearDown(() {
    ApiService.client = http.Client();
    AuthService.getTokenOverride = null;
  });

  Map<String, dynamic> verification({
    String phone = 'VERIFIED',
    String onSite = 'PASSED',
  }) =>
      {
        'phone': phone,
        'location': 'CONFIRMED',
        'onSite': onSite,
        'photos': 'SUBMITTED',
        'documents': 'NOT_SUBMITTED',
        'authority': 'NOT_ESTABLISHED',
        'badgeEarned': false,
      };

  Map<String, dynamic> pendingJson({
    Map<String, dynamic>? verification,
    bool gpsVerified = true,
    String landlordPhone = '+254700000001',
    List<String> imageUrls = const [],
  }) =>
      {
        'id': 5,
        'title': 'Newly Built Bedsitter in Embakasi',
        'location': 'Kayole',
        'price': 10000,
        'bedrooms': 1,
        'type': 'RENTAL',
        'landlordName': 'Mama Wanjiku',
        'landlordPhone': landlordPhone,
        'available': true,
        'status': 'PENDING_VERIFICATION',
        'gpsVerified': gpsVerified,
        'verification': verification,
        'imageUrls': imageUrls,
        'documentUrls': <String>[],
        'listedAt':
            DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
      };

  void stubQueue(Map<String, dynamic> property) {
    ApiService.client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path.endsWith('/api/admin/pending-verifications')) {
        return http.Response(jsonEncode([property]), 200,
            headers: {'content-type': 'application/json'});
      }
      if (request.method == 'POST') {
        posts.add(request);
        return http.Response('{}', 200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response('', 404);
    });
  }

  Future<void> pumpQueue(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdminPendingVerificationsPage(),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> openSheet(WidgetTester tester) async {
    await pumpQueue(tester);
    await tester.tap(find.text('Audit & Inspect Proofs'));
    await tester.pumpAndSettle();
  }

  Finder inSheet(Finder matching) => find.descendant(
        of: find.byType(DraggableScrollableSheet),
        matching: matching,
      );

  group('queue card', () {
    testWidgets('shows the backend\'s phone, GPS and photo states',
        (tester) async {
      stubQueue(pendingJson(verification: verification()));
      await pumpQueue(tester);

      expect(find.text('Phone'), findsOneWidget);
      expect(find.text('GPS'), findsOneWidget);
      expect(find.text('Photos pending'), findsOneWidget);
    });

    testWidgets('reports an unverified phone as unverified', (tester) async {
      stubQueue(pendingJson(verification: verification(phone: 'UNVERIFIED')));
      await pumpQueue(tester);

      expect(find.text('Phone unverified'), findsOneWidget);
      expect(find.text('Phone'), findsNothing);
    });

    testWidgets('never assumes a phone check when the backend sent none',
        (tester) async {
      stubQueue(pendingJson());
      await pumpQueue(tester);

      expect(find.text('GPS'), findsOneWidget);
      expect(find.textContaining('Phone'), findsNothing);
      expect(find.text('Phone SMS'), findsNothing);
    });
  });

  group('audit sheet', () {
    testWidgets('shows the landlord and the real phone and GPS checks',
        (tester) async {
      stubQueue(pendingJson(verification: verification()));
      await openSheet(tester);

      expect(inSheet(find.text('Mama Wanjiku')), findsOneWidget);
      expect(inSheet(find.text('Phone: +254700000001')), findsOneWidget);
      expect(inSheet(find.text('Phone')), findsOneWidget);
      expect(inSheet(find.text('GPS')), findsOneWidget);
    });

    testWidgets('does not claim a phone check it cannot see', (tester) async {
      stubQueue(pendingJson(landlordPhone: ''));
      await openSheet(tester);

      expect(inSheet(find.text('No phone number on file')), findsOneWidget);
      expect(find.text('SMS Verified'), findsNothing);
      expect(inSheet(find.text('Phone')), findsNothing,
          reason: 'no verification record, so no phone check is shown');
    });

    testWidgets('says no screening result is recorded', (tester) async {
      stubQueue(pendingJson(verification: verification()));
      await openSheet(tester);

      expect(find.text('AUTOMATED SCREENING'), findsOneWidget);
      expect(find.text('NOT RECORDED'), findsOneWidget);
      expect(find.text('AI VERIFICATION SIGNALS'), findsNothing);
      expect(find.text('PASSED'), findsNothing);
      expect(find.text('ANALYSED'), findsNothing);
      expect(find.text('CHECKED'), findsNothing);
    });

    testWidgets('labels the buttons as the photo decisions they are',
        (tester) async {
      stubQueue(pendingJson(verification: verification()));
      await openSheet(tester);

      expect(find.text('Approve photos'), findsOneWidget);
      expect(find.text('Reject photos'), findsOneWidget);
      expect(find.text('Grant VERIFIED'), findsNothing);
      expect(find.text('Reject Proofs'), findsNothing);
    });

    testWidgets('approving shows the recorded checks, then posts the approval',
        (tester) async {
      stubQueue(pendingJson(verification: verification(phone: 'UNVERIFIED')));
      await openSheet(tester);

      await tester.tap(find.text('Approve photos'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Owner phone: not verified'), findsOneWidget);
      expect(find.textContaining('On-site GPS: passed'), findsOneWidget);
      expect(posts, isEmpty, reason: 'nothing is sent before confirming');

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(posts, hasLength(1));
      expect(posts.single.url.path,
          endsWith('/api/admin/properties/5/approve-photos'));
    });

    testWidgets('the approval dialog omits the phone line when it is unknown',
        (tester) async {
      stubQueue(pendingJson());
      await openSheet(tester);

      await tester.tap(find.text('Approve photos'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Owner phone'), findsNothing);
      expect(find.textContaining('On-site GPS: passed'), findsOneWidget);
    });

    testWidgets('cancelling the approval sends nothing', (tester) async {
      stubQueue(pendingJson(verification: verification()));
      await openSheet(tester);

      await tester.tap(find.text('Approve photos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(posts, isEmpty);
    });

    testWidgets('rejecting posts the typed reason', (tester) async {
      stubQueue(pendingJson(verification: verification()));
      await openSheet(tester);

      await tester.tap(find.text('Reject photos'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Blurry photos');
      await tester.tap(find.text('Confirm Reject'));
      await tester.pumpAndSettle();

      expect(posts, hasLength(1));
      expect(posts.single.url.path,
          endsWith('/api/admin/properties/5/reject-photos'));
      expect(jsonDecode(posts.single.body), {'reason': 'Blurry photos'});
    });

    testWidgets('rejecting without a reason sends a photo-specific default',
        (tester) async {
      stubQueue(pendingJson(verification: verification()));
      await openSheet(tester);

      await tester.tap(find.text('Reject photos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm Reject'));
      await tester.pumpAndSettle();

      expect(jsonDecode(posts.single.body),
          {'reason': 'Photos did not meet our guidelines'});
    });
  });

  group('listing photos', () {
    const photos = [
      'https://example.test/a.jpg',
      'https://example.test/b.jpg',
      'https://example.test/c.jpg',
    ];

    Finder gridPhoto(int index) => find
        .descendant(
          of: find.byType(GridView),
          matching: find.byType(CachedNetworkImage),
        )
        .at(index);

    Future<void> openPhoto(WidgetTester tester, int index) async {
      stubQueue(pendingJson(verification: verification(), imageUrls: photos));
      await openSheet(tester);
      await tester.ensureVisible(gridPhoto(index));
      await tester.pumpAndSettle();
      await tester.tap(gridPhoto(index));
      await tester.pumpAndSettle();
    }

    Finder viewerText(String text) => find.descendant(
          of: find.byType(FullScreenImageGallery),
          matching: find.text(text),
        );

    testWidgets('tapping a photo opens the shared viewer on that photo',
        (tester) async {
      await openPhoto(tester, 1);

      expect(find.byType(FullScreenImageGallery), findsOneWidget);
      expect(viewerText('2 / 3'), findsOneWidget);
    });

    testWidgets('the viewer\'s close button returns to the audit sheet',
        (tester) async {
      await openPhoto(tester, 0);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(find.byType(FullScreenImageGallery), findsNothing);
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    });

    testWidgets('dragging the photo down dismisses the viewer, not the sheet',
        (tester) async {
      await openPhoto(tester, 0);

      await tester.drag(
        find.descendant(
          of: find.byType(FullScreenImageGallery),
          matching: find.byType(PageView),
        ),
        const Offset(0, 300),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FullScreenImageGallery), findsNothing);
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    });
  });
}
