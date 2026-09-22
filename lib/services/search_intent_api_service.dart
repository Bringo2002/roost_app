import 'package:roost_app/services/api_service.dart';

/// Structured filters extracted by GeminiSearchIntentService on the
/// backend, for search queries the local regex parser
/// (SearchPage._parseSearchIntent) couldn't handle.
class AiSearchIntent {
  const AiSearchIntent({
    this.minPrice,
    this.maxPrice,
    this.houseType,
    required this.furnished,
    required this.parking,
    required this.wifi,
    required this.water,
    required this.security,
    required this.verifiedOnly,
    this.locationHint,
    required this.remainingKeywords,
  });

  final double? minPrice;
  final double? maxPrice;
  final String? houseType;
  final bool furnished;
  final bool parking;
  final bool wifi;
  final bool water;
  final bool security;
  final bool verifiedOnly;
  final String? locationHint;
  final String remainingKeywords;

  factory AiSearchIntent.fromJson(Map<String, dynamic> json) {
    return AiSearchIntent(
      minPrice: (json['minPrice'] as num?)?.toDouble(),
      maxPrice: (json['maxPrice'] as num?)?.toDouble(),
      houseType: json['houseType'] as String?,
      furnished: json['furnished'] as bool? ?? false,
      parking: json['parking'] as bool? ?? false,
      wifi: json['wifi'] as bool? ?? false,
      water: json['water'] as bool? ?? false,
      security: json['security'] as bool? ?? false,
      verifiedOnly: json['verifiedOnly'] as bool? ?? false,
      locationHint: json['locationHint'] as String?,
      remainingKeywords: json['remainingKeywords'] as String? ?? '',
    );
  }
}

/// Client for the AI-assisted search fallback (`POST
/// /api/search/parse-intent`). Meant to be called only when the local
/// regex parser extracts nothing useful, and only on explicit search
/// submission -- never on every keystroke, since each call costs a
/// real Gemini request. Server-side rate-limited per IP regardless.
class SearchIntentApiService {
  SearchIntentApiService._();

  /// Returns null on any failure (network error, rate limit, API not
  /// configured) -- callers should fall back to a plain keyword search
  /// on the original query, which is always safe.
  static Future<AiSearchIntent?> parseIntent(String query) async {
    try {
      final response = await ApiService.post('/api/search/parse-intent', {'query': query});
      final json = response as Map<String, dynamic>;
      if (json['available'] != true) return null;
      return AiSearchIntent.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}
