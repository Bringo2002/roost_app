import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/utils/gps_verification_message.dart';

void main() {
  group('gpsVerificationFailureMessage', () {
    test("shows the backend's reason when it gave one", () {
      final error = ApiException(
        'We couldn\'t find "Kilimani" on the map. Add the neighbourhood and '
        'town and try again.',
        statusCode: 400,
      );

      expect(
        gpsVerificationFailureMessage(error),
        'We couldn\'t find "Kilimani" on the map. Add the neighbourhood and '
        'town and try again.',
      );
    });

    test('shows a temporary-outage message as the backend worded it', () {
      final error = ApiException(
        "We couldn't check the address just now. Please try again in a few "
        'minutes.',
        statusCode: 503,
      );

      expect(gpsVerificationFailureMessage(error), error.message);
    });

    test('falls back to generic advice for an error with no reason of its own',
        () {
      expect(
        gpsVerificationFailureMessage(StateError('boom')),
        contains("Make sure you're at the property"),
      );
    });
  });
}
