import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/models/property_verification.dart';

Map<String, dynamic> json({Map<String, dynamic> overrides = const {}}) => {
      'phone': 'VERIFIED',
      'location': 'CONFIRMED',
      'onSite': 'PASSED',
      'photos': 'APPROVED',
      'documents': 'ACCEPTED',
      'authority': 'NOT_ESTABLISHED',
      'badgeEarned': true,
      ...overrides,
    };

void main() {
  group('PropertyVerification.fromJson', () {
    test('reads every state and the badge', () {
      final v = PropertyVerification.fromJson(json());

      expect(v.phone, PhoneState.verified);
      expect(v.location, LocationState.confirmed);
      expect(v.onSite, OnSiteState.passed);
      expect(v.photos, PhotosState.approved);
      expect(v.documents, DocumentsState.accepted);
      expect(v.authority, AuthorityState.notEstablished);
      expect(v.badgeEarned, isTrue);
    });

    test('reads multi-word states, including the reserved ones', () {
      final v = PropertyVerification.fromJson(json(overrides: {
        'onSite': 'NOT_ATTEMPTED',
        'photos': 'UNDER_REVIEW',
        'documents': 'UNDER_REVIEW',
        'location': 'CHANGED',
        'badgeEarned': false,
      }));

      expect(v.onSite, OnSiteState.notAttempted);
      expect(v.photos, PhotosState.underReview);
      expect(v.documents, DocumentsState.underReview);
      expect(v.location, LocationState.changed);
      expect(v.badgeEarned, isFalse);
    });

    test('throws on a state it does not know rather than guessing', () {
      expect(
        () => PropertyVerification.fromJson(
            json(overrides: {'photos': 'SPARKLING'})),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws on a missing state or badge instead of defaulting', () {
      expect(
        () => PropertyVerification.fromJson(json()..remove('phone')),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => PropertyVerification.fromJson(json()..remove('badgeEarned')),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
