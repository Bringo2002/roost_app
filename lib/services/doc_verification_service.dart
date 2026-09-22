import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:roost_app/services/api_service.dart';

// ─── Result model ─────────────────────────────────────────────────────────────

enum DocRiskLevel {
  /// Tier 1 hard block – do not allow submission.
  rejected,

  /// Tier 2 flagged by AI – allow submission but route to manual admin review.
  flagged,

  /// AI analysis confident the document looks authentic.
  verified,

  /// Gemini API not configured – skip Tier 2, route to manual admin review.
  pendingReview,
}

class DocVerificationResult {
  const DocVerificationResult({
    required this.riskLevel,
    required this.flags,
    this.extractedName,
    this.nameMismatch = false,
    this.confidence = 0.0,
    this.aiDocType,
    this.tier1RejectionReason,
  });

  final DocRiskLevel riskLevel;
  final List<String> flags;
  final String? extractedName;
  final bool nameMismatch;
  final double confidence;
  final String? aiDocType;
  final String? tier1RejectionReason;

  bool get isHardRejected => riskLevel == DocRiskLevel.rejected;

  String get summaryLabel {
    switch (riskLevel) {
      case DocRiskLevel.rejected:
        return 'Rejected: ${tier1RejectionReason ?? 'Invalid document'}';
      case DocRiskLevel.flagged:
        return 'Flagged — submitted for admin review';
      case DocRiskLevel.verified:
        return 'AI verified — looks authentic';
      case DocRiskLevel.pendingReview:
        return 'Submitted for admin review';
    }
  }

  String get flagsReadable => flags.isEmpty
      ? 'None'
      : flags
          .map((f) => f.replaceAll('_', ' ').toLowerCase())
          .join(', ');
}

// ─── Service ──────────────────────────────────────────────────────────────────

class DocVerificationService {
  DocVerificationService._();

  static const int _maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB

  static const _magicBytes = <String, List<int>>{
    'pdf': [0x25, 0x50, 0x44, 0x46],
    'jpg': [0xFF, 0xD8, 0xFF],
    'jpeg': [0xFF, 0xD8, 0xFF],
    'png': [0x89, 0x50, 0x4E, 0x47],
  };

  // ── Tier 1 ──────────────────────────────────────────────────────────────

  static Future<DocVerificationResult> runTier1({
    required Uint8List bytes,
    required String fileName,
    required String declaredDocType,
    List<String>? existingHashes,
  }) async {
    // 1. File size
    if (bytes.length > _maxFileSizeBytes) {
      return const DocVerificationResult(
        riskLevel: DocRiskLevel.rejected,
        flags: ['FILE_TOO_LARGE'],
        tier1RejectionReason:
            'File exceeds 10 MB. Please compress or use a different format.',
      );
    }

    // 2. Magic bytes
    final ext = fileName.split('.').last.toLowerCase();
    if (!_isMimeValid(bytes, ext)) {
      return DocVerificationResult(
        riskLevel: DocRiskLevel.rejected,
        flags: const ['MIME_MISMATCH'],
        tier1RejectionReason:
            'File does not appear to be a valid $ext. It may be corrupted or renamed.',
      );
    }

    // 3. Duplicate hash check against currently uploaded session files
    if (existingHashes != null && existingHashes.contains(_quickHash(bytes))) {
      return const DocVerificationResult(
        riskLevel: DocRiskLevel.rejected,
        flags: ['DUPLICATE_HASH'],
        tier1RejectionReason:
            'This exact document is already attached to this listing.',
      );
    }

    // 4. EXIF freshness (soft flag only)
    final flags = <String>[];
    if (_isExifTooRecent(bytes)) {
      flags.add('EXIF_TOO_RECENT');
    }

    if (flags.isNotEmpty) {
      return DocVerificationResult(
        riskLevel: DocRiskLevel.flagged,
        flags: flags,
      );
    }

    return const DocVerificationResult(
      riskLevel: DocRiskLevel.pendingReview,
      flags: [],
    );
  }

  // ── Tier 2 (server-side Gemini fraud-check) ─────────────────────────────
  //
  // Calls backend (GeminiDocVerificationService) for server-side Gemini AI.
  static Future<DocVerificationResult> runTier2({
    required Uint8List imageBytes,
    required String declaredDocType,
    String? landlordName,
  }) async {
    try {
      final response = await ApiService.post('/api/documents/verify', {
        'data': base64Encode(imageBytes),
        'declaredDocType': declaredDocType,
      });
      return _parseBackendResponse(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Tier 2 Gemini verification error: $e');
      return const DocVerificationResult(
        riskLevel: DocRiskLevel.pendingReview,
        flags: ['AI_UNAVAILABLE'],
      );
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  static bool _isMimeValid(Uint8List bytes, String ext) {
    final sig = _magicBytes[ext];
    if (sig == null) return true;
    if (bytes.length < sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (bytes[i] != sig[i]) return false;
    }
    return true;
  }

  static bool _isExifTooRecent(Uint8List bytes) {
    try {
      final limit = bytes.length < 65536 ? bytes.length : 65536;
      final slice = String.fromCharCodes(bytes.sublist(0, limit));
      final regex = RegExp(r'(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})');
      final match = regex.firstMatch(slice);
      if (match == null) return false;
      final dt = DateTime.tryParse(
          '${match.group(1)}-${match.group(2)}-${match.group(3)}T${match.group(4)}:${match.group(5)}:${match.group(6)}');
      if (dt == null) return false;
      return DateTime.now().difference(dt).inHours < 24;
    } catch (_) {
      return false;
    }
  }

  static String _quickHash(Uint8List bytes) {
    var checksum = bytes.length;
    for (var i = 0; i < bytes.length; i += 256) {
      checksum ^= bytes[i];
    }
    final prefix = base64Encode(bytes.sublist(0, bytes.length < 32 ? bytes.length : 32));
    return '${bytes.length}_${checksum}_$prefix';
  }

  /// Reads the already-computed result straight off the backend's JSON
  /// response -- riskLevel and nameMismatch are now decided server-side
  /// (GeminiDocVerificationService), so this is just a straight mapping
  /// rather than the parsing-plus-scoring the client used to do itself.
  static DocVerificationResult _parseBackendResponse(Map<String, dynamic> json) {
    final riskLevel = switch (json['riskLevel'] as String? ?? 'pendingReview') {
      'flagged' => DocRiskLevel.flagged,
      'verified' => DocRiskLevel.verified,
      _ => DocRiskLevel.pendingReview,
    };
    return DocVerificationResult(
      riskLevel: riskLevel,
      flags: List<String>.from(json['flags'] as List? ?? []),
      extractedName: json['extractedName'] as String?,
      nameMismatch: json['nameMismatch'] as bool? ?? false,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      aiDocType: json['aiDocType'] as String?,
    );
  }
}
