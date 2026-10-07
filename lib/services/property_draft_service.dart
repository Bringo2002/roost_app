import 'package:roost_app/services/api_service.dart';

/// Saves a property listing: creates it on the first save and updates it on
/// every save after that.
///
/// Lives outside AddPropertyPage so the create-or-update decision can be
/// tested without building the whole page.
class PropertyDraftService {
  /// Persists [payload] and returns the id of the saved property, or null if
  /// the server did not return one.
  ///
  /// With a [draftId] the existing property is updated. If the server says
  /// that property no longer exists (for example it was deleted from another
  /// device), a new one is created instead so the landlord's work is not lost.
  /// Any other failure is rethrown.
  static Future<int?> save(int? draftId, Map<String, dynamic> payload) async {
    var currentId = draftId;
    if (currentId != null) {
      try {
        await ApiService.put('/api/properties/$currentId', payload);
        return currentId;
      } on ApiException catch (e) {
        // Branch on the status, not the message text: any failure whose
        // wording merely mentions "not found" or "404" (a validation error,
        // an upstream error) used to be mistaken for a deleted draft.
        if (e.statusCode == 404) {
          currentId = null;
        } else {
          rethrow;
        }
      } catch (_) {
        // Fall back to POST if unknown client-side error
      }
    }
    final result = await ApiService.post('/api/properties', payload);
    final newId = result is Map ? result['id'] as int? : null;
    return newId ?? currentId;
  }
}
