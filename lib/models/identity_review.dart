/// One identity document a lister submitted, as an admin sees it. The file
/// itself is fetched separately and never carried in this model.
class IdentityDocument {
  final int id;

  /// `NATIONAL_ID_FRONT`, `NATIONAL_ID_BACK` or `PASSPORT`.
  final String docType;

  /// `SUBMITTED`, `ACCEPTED` or `REJECTED`.
  final String status;

  /// `image/jpeg`, `image/png` or `application/pdf`.
  final String contentType;
  final int sizeBytes;

  /// Why a reviewer rejected it earlier, or null.
  final String? rejectReason;

  const IdentityDocument({
    required this.id,
    required this.docType,
    required this.status,
    required this.contentType,
    required this.sizeBytes,
    this.rejectReason,
  });

  factory IdentityDocument.fromJson(Map<String, dynamic> json) {
    return IdentityDocument(
      id: (json['id'] as num).toInt(),
      docType: json['docType'] as String? ?? '',
      status: json['status'] as String? ?? 'SUBMITTED',
      contentType: json['contentType'] as String? ?? '',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      rejectReason: json['rejectReason'] as String?,
    );
  }

  bool get isPdf => contentType == 'application/pdf';
  bool get isImage => contentType.startsWith('image/');
  bool get wasRejected => status == 'REJECTED';

  String get label {
    switch (docType) {
      case 'NATIONAL_ID_FRONT':
        return 'National ID (front)';
      case 'NATIONAL_ID_BACK':
        return 'National ID (back)';
      case 'PASSPORT':
        return 'Passport';
      default:
        return docType;
    }
  }
}

/// A lister whose identity documents are waiting for a reviewer.
class IdentityReview {
  final int userId;

  /// The name on the lister's account, to compare with the document.
  final String name;
  final List<IdentityDocument> documents;

  const IdentityReview({
    required this.userId,
    required this.name,
    required this.documents,
  });

  factory IdentityReview.fromJson(Map<String, dynamic> json) {
    final docs = (json['documents'] as List? ?? const [])
        .map((d) => IdentityDocument.fromJson(d as Map<String, dynamic>))
        .toList();
    return IdentityReview(
      userId: (json['userId'] as num).toInt(),
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : 'Unnamed lister',
      documents: docs,
    );
  }
}
