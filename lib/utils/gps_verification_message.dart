import 'package:roost_app/services/api_service.dart';

/// The text to show when verifying a listing's location fails.
///
/// The backend explains exactly why (an out-of-date reading, a weak GPS
/// signal, an address it can't find or that doesn't match the pin, or a
/// temporary outage), and each of those needs different advice. So an
/// [ApiException]'s own message is shown as-is. Anything else carries no
/// reason of its own and gets the generic advice.
String gpsVerificationFailureMessage(Object error) {
  if (error is ApiException) return error.message;
  return "Couldn't verify your location. Make sure you're at the property, "
      'then tap "Confirm your GPS location" again.';
}
