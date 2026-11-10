import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:roost_app/models/property_verification.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/auth_service.dart';
import 'package:roost_app/services/property_draft_service.dart';

/// HTTP goes through [ApiService.client] and auth through
/// [AuthService.getTokenOverride]; both are process-wide statics, so they are
/// reset in tearDown.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AuthService.getTokenOverride = () async => 'test-token';
  });

  tearDown(() {
    ApiService.client = http.Client();
    AuthService.getTokenOverride = null;
  });

  /// Routes PUT and POST to canned responses (an empty JSON 200 when not
  /// given) and returns the list that records every request received.
  List<http.Request> stub({http.Response? put, http.Response? post}) {
    final requests = <http.Request>[];
    ApiService.client = MockClient((request) async {
      requests.add(request);
      final response = request.method == 'PUT' ? put : post;
      return response ?? http.Response('{}', 200);
    });
    return requests;
  }

  /// "METHOD /path" for each recorded request, in order.
  List<String> calls(List<http.Request> requests) =>
      requests.map((r) => '${r.method} ${r.url.path}').toList();

  group('PropertyDraftService.save', () {
    test('creates the property when there is no draft yet', () async {
      final requests = stub(post: http.Response('{"id": 41}', 201));

      final id = await PropertyDraftService.save(null, {'title': 'Loft'});

      expect(id, 41);
      expect(calls(requests), ['POST /api/properties']);
      expect(jsonDecode(requests.single.body), {'title': 'Loft'});
    });

    test('updates an existing draft in place', () async {
      final requests = stub();

      final id = await PropertyDraftService.save(7, {'title': 'Loft'});

      expect(id, 7);
      expect(calls(requests), ['PUT /api/properties/7']);
    });

    test('creates a new property when the draft no longer exists', () async {
      final requests = stub(
        put: http.Response('{"error": "Property not found with id: 7"}', 404),
        post: http.Response('{"id": 8}', 201),
      );

      final id = await PropertyDraftService.save(7, {'title': 'Loft'});

      expect(id, 8);
      expect(calls(requests), ['PUT /api/properties/7', 'POST /api/properties']);
    });

    test('also recovers when the 404 has no readable body', () async {
      final requests = stub(
        put: http.Response('', 404),
        post: http.Response('{"id": 8}', 201),
      );

      final id = await PropertyDraftService.save(7, {'title': 'Loft'});

      expect(id, 8);
      expect(calls(requests), ['PUT /api/properties/7', 'POST /api/properties']);
    });

    test('rethrows other failures without creating a duplicate', () async {
      final requests = stub(put: http.Response('{"error": "Unauthorized"}', 403));

      await expectLater(
        PropertyDraftService.save(7, {'title': 'Loft'}),
        throwsA(isA<ApiException>()),
      );
      expect(calls(requests), ['PUT /api/properties/7']);
    });

    // Regression: the old check searched the error text, so a failure that
    // only mentioned "not found" or "404" looked like a deleted draft and a
    // second create was attempted.
    test('does not treat a 400 that mentions "not found" as a deleted draft', () async {
      final requests = stub(put: http.Response('{"error": "User not found"}', 400));

      await expectLater(
        PropertyDraftService.save(7, {'title': 'Loft'}),
        throwsA(isA<ApiException>()),
      );
      expect(calls(requests), ['PUT /api/properties/7']);
    });

    test('does not treat a 500 whose message mentions 404 as a deleted draft', () async {
      final requests = stub(put: http.Response('{"error": "Upstream returned 404"}', 500));

      await expectLater(
        PropertyDraftService.save(7, {'title': 'Loft'}),
        throwsA(isA<ApiException>()),
      );
      expect(calls(requests), ['PUT /api/properties/7']);
    });

    test('returns null when the create response carries no id', () async {
      stub(post: http.Response('{}', 201));

      expect(await PropertyDraftService.save(null, {'title': 'Loft'}), isNull);
    });
  });

  group('PropertyDraftService.statusForProgressSave', () {
    test('saves a new listing as a draft', () {
      expect(PropertyDraftService.statusForProgressSave(null), 'DRAFT');
    });

    test('keeps the status of a listing that is being edited', () {
      for (final status in ['DRAFT', 'PUBLISHED', 'RENTED']) {
        expect(PropertyDraftService.statusForProgressSave(status), status);
      }
    });
  });

  group('PropertyDraftService.saveDraft', () {
    Map<String, dynamic> verification({String onSite = 'NOT_ATTEMPTED'}) => {
          'phone': 'VERIFIED',
          'location': 'CONFIRMED',
          'onSite': onSite,
          'photos': 'SUBMITTED',
          'documents': 'NOT_SUBMITTED',
          'authority': 'NOT_ESTABLISHED',
          'badgeEarned': false,
        };

    test('reports the verification state from an update', () async {
      stub(put: http.Response(
          jsonEncode({'id': 7, 'verification': verification(onSite: 'PASSED')}),
          200));

      final saved = await PropertyDraftService.saveDraft(7, {'title': 'Loft'});

      expect(saved.id, 7);
      expect(saved.verification!.onSite, OnSiteState.passed);
      expect(saved.verification!.photos, PhotosState.submitted);
    });

    test('reports the verification state from a create', () async {
      stub(post: http.Response(
          jsonEncode({'id': 41, 'verification': verification()}), 201));

      final saved = await PropertyDraftService.saveDraft(null, {'title': 'Loft'});

      expect(saved.id, 41);
      expect(saved.verification!.onSite, OnSiteState.notAttempted);
    });

    test('has no verification when the response carries none', () async {
      stub(put: http.Response('{"id": 7}', 200));

      final saved = await PropertyDraftService.saveDraft(7, {'title': 'Loft'});

      expect(saved.id, 7);
      expect(saved.verification, isNull);
    });

    test('a deleted draft is recreated and the new listing\'s state reported',
        () async {
      final requests = stub(
        put: http.Response('{"error": "Property not found"}', 404),
        post: http.Response(
            jsonEncode({'id': 9, 'verification': verification()}), 200),
      );

      final saved = await PropertyDraftService.saveDraft(7, {'title': 'Loft'});

      expect(calls(requests), ['PUT /api/properties/7', 'POST /api/properties']);
      expect(saved.id, 9);
      expect(saved.verification, isNotNull);
    });

    test('a malformed verification fails loudly and is not POSTed again',
        () async {
      final requests = stub(put: http.Response(
          jsonEncode({'id': 7, 'verification': {'phone': 'NOPE'}}), 200));

      await expectLater(
        PropertyDraftService.saveDraft(7, {'title': 'Loft'}),
        throwsA(isA<FormatException>()),
      );
      expect(calls(requests), ['PUT /api/properties/7'],
          reason: 'must not fall back to creating a duplicate listing');
    });
  });
}
