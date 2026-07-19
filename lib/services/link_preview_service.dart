import 'package:http/http.dart' as http;

class LinkPreviewData {
  final String url;
  final String title;
  final String? description;
  final String? imageUrl;

  LinkPreviewData({
    required this.url,
    required this.title,
    this.description,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
        'url': url,
        'title': title,
        'description': description,
        'imageUrl': imageUrl,
      };

  factory LinkPreviewData.fromJson(Map<String, dynamic> json) {
    return LinkPreviewData(
      url: json['url'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      imageUrl: json['imageUrl'],
    );
  }
}

class LinkPreviewService {
  static final Map<String, LinkPreviewData?> _cache = {};

  /// Extracts the first URL from a string, or returns null if none found.
  static String? extractUrl(String text) {
    final regExp = RegExp(
      r'https?://[^\s$.?#].[^\s]*',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(text);
    return match?.group(0);
  }

  /// Fetches OG metadata for a URL. Returns null on failure or if no title
  /// could be resolved. Caches results in-memory.
  static Future<LinkPreviewData?> fetchPreview(String url) async {
    if (_cache.containsKey(url)) {
      return _cache[url];
    }

    try {
      final uri = Uri.parse(url);
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _cache[url] = null;
        return null;
      }

      final html = response.body;
      final title = _getMetaTag(html, 'og:title') ?? _getTitleTag(html);
      if (title == null || title.trim().isEmpty) {
        _cache[url] = null;
        return null;
      }

      final description = _getMetaTag(html, 'og:description') ??
          _getMetaTag(html, 'description');
      
      var imageUrl = _getMetaTag(html, 'og:image');
      if (imageUrl != null && imageUrl.startsWith('/')) {
        // Resolve relative paths
        imageUrl = '${uri.scheme}://${uri.host}$imageUrl';
      }

      final data = LinkPreviewData(
        url: url,
        title: title.trim(),
        description: description?.trim(),
        imageUrl: imageUrl?.trim(),
      );

      _cache[url] = data;
      return data;
    } catch (_) {
      _cache[url] = null;
      return null;
    }
  }

  static String? _getMetaTag(String html, String property) {
    // Try property="property"
    final regExp1 = RegExp(
      'meta\\s+[^>]*property=["\']${RegExp.escape(property)}["\'][^>]*content=["\']([^"\']*)["\']',
      caseSensitive: false,
    );
    var match = regExp1.firstMatch(html);
    if (match != null) return _decodeHtmlEntities(match.group(1));

    // Try content="content" before property="property"
    final regExp2 = RegExp(
      'meta\\s+[^>]*content=["\']([^"\']*)["\'][^>]*property=["\']${RegExp.escape(property)}["\']',
      caseSensitive: false,
    );
    match = regExp2.firstMatch(html);
    if (match != null) return _decodeHtmlEntities(match.group(1));

    // Try name="property"
    final regExp3 = RegExp(
      'meta\\s+[^>]*name=["\']${RegExp.escape(property)}["\'][^>]*content=["\']([^"\']*)["\']',
      caseSensitive: false,
    );
    match = regExp3.firstMatch(html);
    if (match != null) return _decodeHtmlEntities(match.group(1));

    return null;
  }

  static String? _getTitleTag(String html) {
    final regExp = RegExp(
      '<title[^>]*>([^<]*)</title>',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(html);
    return match != null ? _decodeHtmlEntities(match.group(1)) : null;
  }

  static String? _decodeHtmlEntities(String? text) {
    if (text == null) return null;
    // Basic entity decoding to keep the display clean
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
  }
}
