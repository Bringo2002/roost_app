import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static String get _apiKey {
    const envKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
    if (envKey.isNotEmpty) return envKey;
    try {
      final sysKey = Platform.environment['GEMINI_API_KEY'];
      if (sysKey != null && sysKey.isNotEmpty) return sysKey;
    } catch (_) {}
    try {
      final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (home != null) {
        final envFile = File('$home/.env');
        if (envFile.existsSync()) {
          final lines = envFile.readAsLinesSync();
          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.startsWith('GEMINI_API_KEY=')) {
              return trimmed.substring('GEMINI_API_KEY='.length).trim();
            }
          }
        }
      }
    } catch (_) {}
    return '';
  }

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

    // 3. Duplicate hash
    if (await _isDuplicateFile(bytes)) {
      return const DocVerificationResult(
        riskLevel: DocRiskLevel.rejected,
        flags: ['DUPLICATE_HASH'],
        tier1RejectionReason:
            'This exact document was already submitted. Please use a different file.',
      );
    }

    // 4. EXIF freshness (soft flag only)
    final flags = <String>[];
    if (_isExifTooRecent(bytes)) {
      flags.add('EXIF_TOO_RECENT');
    }

    // Store hash for future duplicate detection
    await _storeFileHash(bytes);

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

  // ── Tier 2 ──────────────────────────────────────────────────────────────

  static Future<DocVerificationResult> runTier2({
    required Uint8List imageBytes,
    required String declaredDocType,
    String? landlordName,
  }) async {
    if (_apiKey.isEmpty) {
      return const DocVerificationResult(
        riskLevel: DocRiskLevel.pendingReview,
        flags: ['NO_API_KEY'],
      );
    }

    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
      final prompt = _buildPrompt(declaredDocType, landlordName);
      final content = [
        Content.multi([
          DataPart('image/jpeg', imageBytes),
          TextPart(prompt),
        ]),
      ];
      final response = await model.generateContent(content);
      final rawText = response.text ?? '';
      return _parseGeminiResponse(rawText, landlordName);
    } catch (_) {
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

  static Future<bool> _isDuplicateFile(Uint8List bytes) async {
    final hash = _quickHash(bytes);
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('roost_doc_hashes') ?? [];
    return stored.contains(hash);
  }

  static Future<void> _storeFileHash(Uint8List bytes) async {
    final hash = _quickHash(bytes);
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('roost_doc_hashes') ?? [];
    if (!stored.contains(hash)) {
      stored.add(hash);
      if (stored.length > 100) stored.removeAt(0);
      await prefs.setStringList('roost_doc_hashes', stored);
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

  static String _buildPrompt(String declaredDocType, String? landlordName) {
    return '''
You are a document authentication expert for a Kenyan rental property platform.
Analyze this document image and respond ONLY with a valid JSON object — no markdown, no explanation.

Required JSON fields:
{
  "docType": "<what type of document this actually is>",
  "isAuthentic": <true|false>,
  "confidence": <0.0 to 1.0>,
  "extractedName": "<full name found on document, or null>",
  "flags": ["<FLAG_1>"],
  "summary": "<one sentence>"
}

Flags to use (all that apply):
WRONG_DOC_TYPE, TEMPLATE_MISMATCH, DIGITALLY_ALTERED, LOW_QUALITY, MISSING_OFFICIAL_SEAL, NAME_NOT_READABLE${landlordName != null ? ', NAME_MISMATCH (if extractedName clearly differs from "$landlordName")' : ''}

Kenyan title deeds: green/cream, issued by Ministry of Lands. National IDs: blue/beige with coat of arms. Utility bills: KPLC or Nairobi Water logo with account number.
''';
  }

  static DocVerificationResult _parseGeminiResponse(
      String rawText, String? landlordName) {
    try {
      final cleaned = rawText
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();
      final json = jsonDecode(cleaned) as Map<String, dynamic>;

      final isAuthentic = json['isAuthentic'] as bool? ?? false;
      final confidence = (json['confidence'] as num?)?.toDouble() ?? 0.0;
      final extractedName = json['extractedName'] as String?;
      final aiDocType = json['docType'] as String?;
      final flags = List<String>.from(json['flags'] as List? ?? []);

      bool nameMismatch = flags.contains('NAME_MISMATCH');
      if (!nameMismatch &&
          landlordName != null &&
          extractedName != null &&
          extractedName.isNotEmpty) {
        nameMismatch = !_fuzzyNameMatch(landlordName, extractedName);
        if (nameMismatch) flags.add('NAME_MISMATCH');
      }

      final level = (!isAuthentic || confidence < 0.4 || flags.isNotEmpty)
          ? DocRiskLevel.flagged
          : DocRiskLevel.verified;

      return DocVerificationResult(
        riskLevel: level,
        flags: flags,
        extractedName: extractedName,
        nameMismatch: nameMismatch,
        confidence: confidence,
        aiDocType: aiDocType,
      );
    } catch (_) {
      return const DocVerificationResult(
        riskLevel: DocRiskLevel.pendingReview,
        flags: ['AI_PARSE_ERROR'],
      );
    }
  }

  static bool _fuzzyNameMatch(String nameA, String nameB) {
    String norm(String s) =>
        s.toLowerCase().replaceAll(RegExp(r"[^a-z\s]"), '').trim();
    final a = norm(nameA).split(RegExp(r'\s+')).toSet();
    final b = norm(nameB).split(RegExp(r'\s+')).toSet();
    final intersection = a.intersection(b).length;
    final smaller = a.length < b.length ? a.length : b.length;
    if (smaller == 0) return false;
    return intersection / smaller >= 0.6;
  }
}
