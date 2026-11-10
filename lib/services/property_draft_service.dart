import 'package:roost_app/models/property_verification.dart';
import 'package:roost_app/services/api_service.dart';

/// Saves a property listing: creates it on the first save and updates it on
/// every save after that.
///
/// Lives outside AddPropertyPage so the create-or-update decision can be
/// tested without building the whole page.
class PropertyDraftService {
  /// The `status` to send when saving progress (autosave, "Save Draft",
  /// location capture) rather than publishing.
  ///
  /// A new listing is saved as a `DRAFT`. A listing that is being edited keeps
  /// the status it already has: the backend overwrites the whole listing on
  /// every save, so sending `DRAFT` for a live listing would silently take it
  /// off the market. The status must be sent explicitly rather than omitted,
  /// because the backend treats a missing status as `PUBLISHED`.
  static String statusForProgressSave(String? editingStatus) =>
      editingStatus ?? 'DRAFT';

  /// Persists [payload] and returns the id of the saved property, or null if
  /// the server did not return one. See [saveDraft] for how it behaves.
  static Future<int?> save(int? draftId, Map<String, dynamic> payload) async =>
      (await saveDraft(draftId, payload)).id;

  /// Persists [payload] and reports what the server says about the saved
  /// listing: its id, and its verification state.
  ///
  /// With a [draftId] the existing property is updated. If the server says
  /// that property no longer exists (for example it was deleted from another
  /// device), a new one is created instead so the landlord's work is not lost.
  /// Any other failure is rethrown.
  ///
  /// The verification state matters because a save can clear a verification
  /// (changing the address or moving the pin does), so the caller has to show
  /// what the server now says rather than what it remembers.
  static Future<SavedDraft> saveDraft(
      int? draftId, Map<String, dynamic> payload) async {
    var currentId = draftId;
    if (currentId != null) {
      Object? updated;
      var wasUpdated = false;
      try {
        updated = await ApiService.put('/api/properties/$currentId', payload);
        wasUpdated = true;
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
      // Read outside the try above: a malformed verification must surface as
      // an error, not be mistaken for a failed update and POSTed again as a
      // duplicate listing.
      if (wasUpdated) {
        return SavedDraft(id: currentId, verification: _verificationOf(updated));
      }
    }
    final result = await ApiService.post('/api/properties', payload);
    final newId = result is Map ? result['id'] as int? : null;
    return SavedDraft(
        id: newId ?? currentId, verification: _verificationOf(result));
  }

  /// The `verification` object of an owner response, or null when the
  /// response carries none.
  static PropertyVerification? _verificationOf(Object? response) {
    if (response is! Map || response['verification'] is! Map) return null;
    return PropertyVerification.fromJson(
        Map<String, dynamic>.from(response['verification'] as Map));
  }
}

/// What [PropertyDraftService.saveDraft] reports about a saved listing.
class SavedDraft {
  /// Creates a result.
  const SavedDraft({required this.id, this.verification});

  /// The saved property's id, or null if the server did not return one.
  final int? id;

  /// The backend's verification state for the listing right after the save,
  /// or null when the response did not carry one.
  final PropertyVerification? verification;
}
