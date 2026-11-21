import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:roost_app/config.dart';
import 'package:roost_app/models/move_in_inspection.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/auth_service.dart';
import 'package:roost_app/services/move_in_inspection_api_service.dart';

/// [MoveInInspectionApiService.saveProgress] is what the inspection wizard
/// calls for every autosave and when finishing. These tests pin what it puts
/// on the wire, in particular that signatures reach the backend.
///
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
    AuthService.refreshTokenOverride = null;
  });

  MoveInInspection newInspection() => MoveInInspection.createNew(
        propertyId: 7,
        propertyTitle: 'Kilimani 2BR',
        tenantName: 'Brian',
      )..id = '42';

  /// Answers every request with the inspection echoed back and returns the
  /// list that records each request received.
  List<http.Request> capture(MoveInInspection echo) {
    final requests = <http.Request>[];
    ApiService.client = MockClient((request) async {
      requests.add(request);
      return http.Response(jsonEncode(echo.toJson()), 200);
    });
    return requests;
  }

  Map<String, dynamic> bodyOf(http.Request request) =>
      jsonDecode(request.body) as Map<String, dynamic>;

  group('saveProgress', () {
    test('sends rooms and captured signatures, but not meter readings',
        () async {
      final inspection = newInspection()
        ..tenantSignature = 'https://img.example/tenant.png'
        ..landlordSignature = 'https://img.example/landlord.png'
        ..meterElectricity = '1042'
        ..meterWater = '88';
      final requests = capture(inspection);

      await MoveInInspectionApiService.saveProgress('42', inspection);

      final request = requests.single;
      expect(request.method, 'PUT');
      expect(request.url.toString(), '${AppConfig.baseUrl}/api/inspections/42');
      final body = bodyOf(request);
      expect(body['tenantSignature'], 'https://img.example/tenant.png');
      expect(body['landlordSignature'], 'https://img.example/landlord.png');
      expect(body['rooms'], hasLength(5));
      expect(body.containsKey('meterElectricity'), isFalse);
      expect(body.containsKey('meterWater'), isFalse);
      expect(body.containsKey('markComplete'), isFalse);
    });

    test('omits signatures that have not been captured yet', () async {
      final inspection = newInspection();
      final requests = capture(inspection);

      await MoveInInspectionApiService.saveProgress('42', inspection);

      final body = bodyOf(requests.single);
      expect(body.containsKey('tenantSignature'), isFalse);
      expect(body.containsKey('landlordSignature'), isFalse);
    });

    test('completing also sends meter readings and markComplete', () async {
      final inspection = newInspection()
        ..tenantSignature = 'https://img.example/tenant.png'
        ..meterElectricity = '1042'
        ..meterWater = '88';
      final requests = capture(inspection);

      await MoveInInspectionApiService.saveProgress(
        '42',
        inspection,
        markComplete: true,
      );

      final body = bodyOf(requests.single);
      expect(body['tenantSignature'], 'https://img.example/tenant.png');
      expect(body['meterElectricity'], '1042');
      expect(body['meterWater'], '88');
      expect(body['markComplete'], isTrue);
    });
  });
}
