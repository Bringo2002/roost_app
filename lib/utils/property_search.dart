import 'dart:math' as math;

import 'package:roost_app/models/property.dart';

/// What a free-text search query was understood to mean: structured
/// constraints (price, house type, furnishing, amenities) plus whatever
/// plain words are left over.
class SearchIntent {
  const SearchIntent({
    this.tokens = const [],
    this.minPrice,
    this.maxPrice,
    this.houseType,
    this.furnished = false,
    this.unfurnished = false,
    this.amenities = const [],
  });

  /// Leftover words after every structured part was extracted. ALL of
  /// them must match somewhere in a property for it to be a result.
  final List<String> tokens;
  final double? minPrice;
  final double? maxPrice;

  /// Canonical backend value: BEDSITTER / STUDIO / 1BR / 2BR / 3BR+.
  final String? houseType;
  final bool furnished;
  final bool unfurnished;

  /// Canonical amenity keys (see [PropertySearch]) the query asked for.
  final List<String> amenities;

  String get remainingText => tokens.join(' ');

  /// True when the query contained anything the local parser could turn
  /// into a real constraint. When false, the caller may escalate to the
  /// server-side AI parser.
  bool get hasStructuredIntent =>
      minPrice != null ||
      maxPrice != null ||
      houseType != null ||
      furnished ||
      unfurnished ||
      amenities.isNotEmpty;
}

class _AmenityDef {
  const _AmenityDef(this.key, this.pattern, this.has, this.words);

  final String key;
  final String pattern;
  final bool Function(Property p) has;

  /// Whole words that, when present in a listing's text, also count as
  /// having the amenity (e.g. the description says "lift").
  final List<String> words;
}

/// Pure, testable free-text property search shared by the home feed and
/// the Search page.
///
/// Compared to the old "whole query must be a substring of title or
/// location" matching, this:
///  * splits the query into words that must ALL match, in any field
///  * searches title, building name, location, description, house type,
///    custom amenities and nearby facilities
///  * understands amenity words (pool, gym, lift, ac, ...) against the
///    listing's amenity flags
///  * tolerates plurals and small typos ("kilimanni")
///  * understands more phrasings of price and bedrooms ("15k to 25k",
///    "20,000", "2-bedroom", "2 br", "bedsiter", "single room")
///  * treats "unfurnished" as the opposite of "furnished"
class PropertySearch {
  PropertySearch._();

  static const Map<String, double> _multipliers = {
    'k': 1000.0,
    'thousand': 1000.0,
    'million': 1000000.0,
  };

  static const Map<String, int> _wordNumbers = {
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
  };

  /// Words that carry no matching value once the structured parts are
  /// extracted, so they must not be required to appear in a listing
  /// ("Kilimani apartment for rent" should just match Kilimani).
  static const Set<String> _stopWords = {
    'a', 'an', 'the', 'and', 'or', 'for', 'to', 'of', 'in', 'at', 'on',
    'near', 'nearby', 'around', 'by', 'with', 'rent', 'rental', 'rentals',
    'let', 'apartment', 'apartments', 'house', 'houses', 'home', 'homes',
    'flat', 'flats', 'unit', 'units', 'place', 'room', 'rooms', 'looking',
    'want', 'need', 'find', 'me', 'my', 'i', 'im', 'am', 'is', 'are',
    'please', 'cheap', 'affordable', 'nice', 'good', 'best', 'available',
    'above', 'plus', 'within', 'under', 'below', 'km', 'kms', 'minutes',
    'mins', 'walk', 'walking', 'distance', 'away', 'from',
  };

  // ── Price patterns ────────────────────────────────────────────────
  static const String _cur = r'(?:ksh|kes|shs?|\$)?\s*';
  static const String _num = r'(\d+(?:\.\d+)?)';
  static const String _suffix = r'\s*(k|thousand|million)?';

  // Distances, times and room counts must never be read as a price
  // ("within 5 km", "under 20 minutes", "over 3 bedrooms").
  static const String _unitGuard =
      r'(?!\s*(?:km|kms|kilomet|meter|metre|min|mile|bed|br\b|bath|year|month|floor|stor|sq|m2))';

  static final RegExp _range = RegExp(
    r'\b(?:between\s+)?' + _cur + _num + _suffix + r'\s*(?:to|-|–|and|until)\s*' + _cur + _num + _suffix + r'\b',
  );
  static final RegExp _upper = RegExp(
    r'\b(?:under|below|less than|lower than|cheaper than|up to|upto|within|max(?:imum)?|not more than|at most|budget(?: of| is)?)\s*' +
        _cur + _num + _suffix + r'\b' + _unitGuard,
  );
  static final RegExp _lower = RegExp(
    r'\b(?:above|over|more than|greater than|from|at least|minimum|min|starting(?: at| from)?)\s*' +
        _cur + _num + _suffix + r'\b' + _unitGuard,
  );
  static final RegExp _postUpper = RegExp(
    r'\b' + _num + _suffix + r'\s*(?:max|maximum|or less|or below|or under|and below|and under|or cheaper)\b',
  );
  static final RegExp _postLower = RegExp(
    r'\b' + _num + _suffix + r'\s*(?:min|minimum|or more|or above|and above|and over)\b',
  );
  // A bare "15k" is read as a budget ceiling; so is a bare 4-7 digit number.
  static final RegExp _bareK = RegExp(r'\b' + _cur + _num + r'\s*(k|thousand)\b');
  static final RegExp _bareBig = RegExp(r'\b(\d{4,7})\b(?!\s*(?:sq|sqft|m2|sqm|km|m\b))');

  // ── House type patterns ───────────────────────────────────────────
  static final RegExp _bedrooms = RegExp(
    r'\b(\d|one|two|three|four|five|six)\s*(?:bed\s?rooms?|bedrms?|bdrms?|brs?|beds?|bhk)\b(?:\s*(?:and above|plus|or more))?',
  );
  static final RegExp _bedsitter = RegExp(r'\b(?:bed\s?sit{1,2}(?:er)?s?|single\s+rooms?)\b');
  static final RegExp _studio = RegExp(r'\bstudios?\b');
  static final RegExp _unfurnished = RegExp(r'\b(?:unfurnished|(?:not|non)\s+furnished)\b');
  static final RegExp _furnished = RegExp(r'\b(?:semi\s+)?furnished\b');

  // ── Amenities ─────────────────────────────────────────────────────
  static final List<_AmenityDef> _amenityDefs = [
    _AmenityDef('parking', r'\bparking\b', (p) => p.parking, ['parking']),
    _AmenityDef('wifi', r'\b(?:wi\s?fi|internet|fib(?:re|er))\b', (p) => p.wifi, ['wifi', 'internet', 'fibre', 'fiber']),
    _AmenityDef('water', r'\bwater\b', (p) => p.water, ['water']),
    _AmenityDef('security', r'\b(?:security|guards?)\b', (p) => p.security, ['security', 'guard', 'guards']),
    _AmenityDef('pool', r'\b(?:swimming\s+pool|pool)\b', (p) => p.pool, ['pool']),
    _AmenityDef('gym', r'\bgym\b', (p) => p.gym, ['gym']),
    _AmenityDef('ac', r'\b(?:ac|air\s?con(?:ditioning|ditioner)?)\b', (p) => p.ac, ['ac', 'aircon']),
    _AmenityDef('heating', r'\bheating\b', (p) => p.heating, ['heating']),
    _AmenityDef('laundry', r'\b(?:laundry|washing machine)\b', (p) => p.laundry, ['laundry']),
    _AmenityDef('dstv', r'\bdstv\b', (p) => p.dstv, ['dstv']),
    _AmenityDef('fence', r'\bfenced?\b', (p) => p.fence, ['fence', 'fenced']),
    _AmenityDef('intercom', r'\bintercom\b', (p) => p.intercom, ['intercom']),
    _AmenityDef('elevator', r'\b(?:elevator|lift)\b', (p) => p.elevator, ['elevator', 'lift']),
    _AmenityDef('caretaker', r'\bcaretaker\b', (p) => p.caretaker, ['caretaker']),
    _AmenityDef('rooftop', r'\broof\s?top\b', (p) => p.rooftop, ['rooftop']),
    _AmenityDef('garden', r'\bgardens?\b', (p) => p.garden, ['garden', 'gardens']),
    _AmenityDef('storage', r'\bstorage\b', (p) => p.storage, ['storage']),
    _AmenityDef('playArea', r'\b(?:play\s?area|playground)\b', (p) => p.playArea, ['playground']),
    _AmenityDef('cleaning', r'\bcleaning\b', (p) => p.cleaning, ['cleaning']),
    _AmenityDef('garbage', r'\bgarbage\b', (p) => p.garbage, ['garbage']),
    _AmenityDef('wheelchair', r'\bwheelchair\b', (p) => p.wheelchair, ['wheelchair']),
    _AmenityDef('solar', r'\bsolar\b', (p) => p.solar, ['solar']),
    _AmenityDef('generator', r'\b(?:generator|backup power)\b', (p) => p.generator, ['generator']),
    _AmenityDef('balcony', r'\bbalcon(?:y|ies)\b', (p) => p.balcony, ['balcony', 'balconies']),
    _AmenityDef('petFriendly', r'\b(?:pet\s?friendly|pets?)\b', (p) => p.petFriendly, ['pets']),
  ];

  static final Map<String, _AmenityDef> _amenityByKey = {
    for (final d in _amenityDefs) d.key: d,
  };
  static final Map<String, RegExp> _amenityPatterns = {
    for (final d in _amenityDefs) d.key: RegExp(d.pattern),
  };

  /// Turns a raw search-box string into a [SearchIntent].
  static SearchIntent parse(String query) {
    var t = ' ${query.toLowerCase()} ';
    t = t.replaceAll('a/c', 'ac');
    // "20,000" -> "20000"
    t = t.replaceAllMapped(RegExp(r'(\d),(?=\d{3})'), (m) => m[1]!);

    double? minPrice;
    double? maxPrice;
    void setMax(double v) => maxPrice = maxPrice == null ? v : math.min(maxPrice!, v);
    void setMin(double v) => minPrice = minPrice == null ? v : math.max(minPrice!, v);
    double value(String n, String? suffix) => double.parse(n) * (_multipliers[suffix] ?? 1.0);

    t = t.replaceAllMapped(_range, (m) {
      final n1 = m[1]!;
      final n2 = m[3]!;
      var s1 = m[2];
      final s2 = m[4];
      // "15 to 25k" -> both in thousands.
      if (s1 == null && s2 != null && double.parse(n1) < double.parse(n2)) s1 = s2;
      final a = value(n1, s1);
      final b = value(n2, s2);
      // "1 to 2 bedroom" is not a price range.
      if (math.max(a, b) < 1000) return m[0]!;
      setMin(math.min(a, b));
      setMax(math.max(a, b));
      return ' ';
    });
    t = t.replaceAllMapped(_upper, (m) {
      setMax(value(m[1]!, m[2]));
      return ' ';
    });
    t = t.replaceAllMapped(_lower, (m) {
      setMin(value(m[1]!, m[2]));
      return ' ';
    });
    t = t.replaceAllMapped(_postUpper, (m) {
      setMax(value(m[1]!, m[2]));
      return ' ';
    });
    t = t.replaceAllMapped(_postLower, (m) {
      setMin(value(m[1]!, m[2]));
      return ' ';
    });
    t = t.replaceAllMapped(_bareK, (m) {
      setMax(value(m[1]!, m[2]));
      return ' ';
    });
    t = t.replaceAllMapped(_bareBig, (m) {
      setMax(double.parse(m[1]!));
      return ' ';
    });

    // Punctuation -> spaces ("2-bedroom", "pet-friendly", "3+").
    t = t.replaceAll(RegExp(r'[-–_/+]'), ' ');
    t = t.replaceAll(RegExp(r'[^a-z0-9.\s]'), ' ');
    t = t.replaceAll(RegExp(r'(?<!\d)\.|\.(?!\d)'), ' ');

    String? houseType;
    final bed = _bedrooms.firstMatch(t);
    if (bed != null) {
      final w = bed[1]!;
      final n = _wordNumbers[w] ?? int.parse(w);
      if (n >= 1) houseType = n == 1 ? '1BR' : (n == 2 ? '2BR' : '3BR+');
      t = t.replaceRange(bed.start, bed.end, ' ');
    } else {
      final candidates = <MapEntry<RegExp, String>>[
        MapEntry(_bedsitter, 'BEDSITTER'),
        MapEntry(_studio, 'STUDIO'),
      ];
      for (final c in candidates) {
        final m = c.key.firstMatch(t);
        if (m != null) {
          houseType = c.value;
          t = t.replaceRange(m.start, m.end, ' ');
          break;
        }
      }
    }

    // "unfurnished" must be checked first: it is NOT "furnished".
    var unfurnished = false;
    var furnished = false;
    if (_unfurnished.hasMatch(t)) {
      unfurnished = true;
      t = t.replaceAll(_unfurnished, ' ');
    }
    if (_furnished.hasMatch(t)) {
      furnished = true;
      t = t.replaceAll(_furnished, ' ');
    }

    final amenities = <String>[];
    for (final def in _amenityDefs) {
      final rx = _amenityPatterns[def.key]!;
      if (rx.hasMatch(t)) {
        amenities.add(def.key);
        t = t.replaceAll(rx, ' ');
      }
    }

    final tokens = <String>[];
    for (final w in t.split(RegExp(r'\s+'))) {
      if (w.isEmpty || _stopWords.contains(w) || tokens.contains(w)) continue;
      // Stray small numbers ("2" from "2-3 bedroom") carry no meaning.
      if (RegExp(r'^\d{1,3}$').hasMatch(w)) continue;
      tokens.add(w);
    }

    return SearchIntent(
      tokens: tokens,
      minPrice: minPrice,
      maxPrice: maxPrice,
      houseType: houseType,
      furnished: furnished,
      unfurnished: unfurnished,
      amenities: amenities,
    );
  }

  /// Whether [p] satisfies every part of [intent].
  static bool matches(Property p, SearchIntent intent) {
    final ht = intent.houseType;
    if (ht != null) {
      final ok = p.houseType.toUpperCase() == ht || (ht == '3BR+' && p.bedrooms >= 3);
      if (!ok) return false;
    }
    if (intent.maxPrice != null && p.price > intent.maxPrice!) return false;
    if (intent.minPrice != null && p.price < intent.minPrice!) return false;
    if (intent.furnished && !p.furnished) return false;
    if (intent.unfurnished && p.furnished) return false;

    if (intent.tokens.isEmpty && intent.amenities.isEmpty) return true;

    final haystack = _haystack(p);
    Set<String>? words;
    Set<String> wordSet() =>
        words ??= haystack.split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty).toSet();

    for (final key in intent.amenities) {
      final def = _amenityByKey[key];
      if (def == null) continue;
      if (def.has(p)) continue;
      final listingWords = wordSet();
      if (def.words.any(listingWords.contains)) continue;
      return false;
    }

    for (final token in intent.tokens) {
      if (!_tokenMatches(token, haystack, wordSet)) return false;
    }
    return true;
  }

  static String _haystack(Property p) {
    return [
      p.title,
      p.buildingName ?? '',
      p.location,
      p.description,
      p.houseType,
      _houseTypeWords(p.houseType),
      ...p.customAmenities,
      for (final f in p.nearbyFacilities) '${f.name} ${f.category}',
    ].join(' ').toLowerCase();
  }

  static String _houseTypeWords(String houseType) {
    switch (houseType.toUpperCase()) {
      case 'BEDSITTER':
        return 'bedsitter bedsit';
      case 'STUDIO':
        return 'studio';
      case '1BR':
        return '1 bedroom one bedroom';
      case '2BR':
        return '2 bedroom two bedroom';
      case '3BR+':
        return '3 bedroom three bedroom';
      default:
        return '';
    }
  }

  static bool _tokenMatches(String token, String haystack, Set<String> Function() wordSet) {
    if (haystack.contains(token)) return true;
    // Simple plural: "gardens" -> "garden".
    if (token.length > 3 && token.endsWith('s') && haystack.contains(token.substring(0, token.length - 1))) {
      return true;
    }
    // Typo tolerance for real words only (not numbers or short tokens).
    final maxDistance = token.length >= 9 ? 2 : (token.length >= 5 ? 1 : 0);
    if (maxDistance == 0 || RegExp(r'\d').hasMatch(token)) return false;
    for (final w in wordSet()) {
      if (w.isEmpty || w[0] != token[0]) continue;
      if (_withinDistance(token, w, maxDistance)) return true;
    }
    return false;
  }

  /// Levenshtein distance check, abandoning early once it can't succeed.
  static bool _withinDistance(String a, String b, int max) {
    if ((a.length - b.length).abs() > max) return false;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final curr = List<int>.filled(b.length + 1, 0);
      curr[0] = i;
      var rowMin = curr[0];
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        curr[j] = math.min(math.min(curr[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
        if (curr[j] < rowMin) rowMin = curr[j];
      }
      if (rowMin > max) return false;
      prev = curr;
    }
    return prev[b.length] <= max;
  }
}
