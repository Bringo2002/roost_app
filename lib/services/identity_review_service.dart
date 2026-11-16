import 'package:flutter/foundation.dart';
import 'package:roost_app/models/identity_review.dart';
import 'package:roost_app/services/api_service.dart';

/// The admin side of identity verification: who is waiting, the files they
/// submitted, and the accept or reject decision.
class IdentityReviewService {
  static const String _base = '/api/admin/verification';

  /// Listers whose identity documents are waiting, oldest account first.
  static Future<List<IdentityReview>> pending() async {
    final json = await ApiService.get('$_base/identity/pending');
    return (json as List)
        .map((j) => IdentityReview.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// The stored file for one document. The server records that it was viewed.
  static Future<Uint8List> file(int documentId) {
    return ApiService.getBytes('$_base/documents/$documentId/file');
  }

  /// Accepts a lister's documents and marks their identity verified.
  static Future<void> accept(int userId) async {
    await ApiService.post('$_base/identity/$userId/accept');
  }

  /// Rejects a lister's documents. [reason] is shown to the lister.
  static Future<void> reject(int userId, String reason) async {
    await ApiService.post('$_base/identity/$userId/reject', {'reason': reason});
  }
}
