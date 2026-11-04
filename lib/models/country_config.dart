import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Budget tier shown during onboarding.
class BudgetOption {
  final String title;
  final String badge;
  final String desc;
  final double minPrice;
  final double maxPrice;

  const BudgetOption({
    required this.title,
    required this.badge,
    required this.desc,
    required this.minPrice,
    required this.maxPrice,
  });
}

/// All region-specific configuration for a supported country.
class CountryConfig {
  final String code;           // ISO 3166-1 alpha-2: 'KE', 'IN', 'NG', etc.
  final String name;           // 'Kenya', 'India', etc.
  final String flag;           // Emoji flag: '🇰🇪', '🇮🇳'
  final String dialCode;       // International dialing prefix: '+254', '+91'
  final String currencyCode;   // ISO 4217: 'KES', 'INR', 'NGN'
  final String currencySymbol; // Display symbol: 'KES', '₹', '₦', '$'
  final String locale;         // Dart/ICU locale for number formatting: 'en_KE', 'en_IN'
  final double priceMin;       // Filter slider minimum
  final double priceMax;       // Filter slider maximum
  final int priceDivisions;    // Slider divisions
  final String searchHint;     // Placeholder in search bar
  final List<BudgetOption> budgets; // Onboarding budget tiers
  final String browsingDesc;   // "Just Browsing" description text
  final LatLng mapCenter;      // Fallback map center when a listing has no pinned lat/lng

  /// Index into [budgets] that should be pre-selected during onboarding.
  /// Based on the most common rental tier in each market.
  final int defaultBudgetIndex;

  /// House type value (e.g. '1BR', 'STUDIO') to pre-select during onboarding.
  /// Based on the most searched property type in each market.
  final String defaultHouseType;

  const CountryConfig({
    required this.code,
    required this.name,
    required this.flag,
    required this.dialCode,
    required this.currencyCode,
    required this.currencySymbol,
    required this.locale,
    required this.priceMin,
    required this.priceMax,
    required this.priceDivisions,
    required this.searchHint,
    required this.budgets,
    required this.browsingDesc,
    required this.mapCenter,
    this.defaultBudgetIndex = 1,
    this.defaultHouseType = '1BR',
  });

  /// Returns a location-aware search placeholder (e.g. "Search rentals in Westlands, 2BR..."
  /// or "Search rentals in Nairobi...") if a specific neighborhood/locality is provided.
  String getDynamicSearchHint([String? locationName]) {
    if (locationName != null && locationName.trim().isNotEmpty) {
      return 'Search rentals in ${locationName.trim()}, 2BR...';
    }
    return searchHint;
  }

  // ── Supported Countries ───────────────────────────────────────────

  // Kenya: Most renters search 1BR in the 15k-30k tier
  static const kenya = CountryConfig(
    code: 'KE',
    name: 'Kenya',
    flag: '🇰🇪',
    dialCode: '+254',
    currencyCode: 'KES',
    currencySymbol: 'KES',
    locale: 'en_KE',
    priceMin: 5000,
    priceMax: 150000,
    priceDivisions: 29,
    searchHint: 'Search rentals by location, e.g. 2BR...',
    browsingDesc: 'Checking Nairobi market prices',
    mapCenter: LatLng(-1.2921, 36.8219), // Nairobi
    defaultBudgetIndex: 1,  // KES 15k – 30k (Popular)
    defaultHouseType: '1BR',
    budgets: [
      BudgetOption(title: 'Under KES 15,000', badge: 'Budget Friendly', desc: 'Affordable studio & bedsitter listings', minPrice: 0, maxPrice: 15000),
      BudgetOption(title: 'KES 15k – 30k', badge: 'Popular', desc: 'Standard 1BR & 2BR apartments', minPrice: 15000, maxPrice: 30000),
      BudgetOption(title: 'KES 30k – 60k', badge: 'Premium', desc: 'Modern 2BR & 3BR in prime areas', minPrice: 30000, maxPrice: 60000),
      BudgetOption(title: 'KES 60,000+', badge: 'Luxury', desc: 'High-end penthouses & serviced units', minPrice: 60000, maxPrice: double.infinity),
    ],
  );

  // India: Most renters search 1BHK (mapped to 1BR) in the ₹10k-25k tier
  static const india = CountryConfig(
    code: 'IN',
    name: 'India',
    flag: '🇮🇳',
    dialCode: '+91',
    currencyCode: 'INR',
    currencySymbol: '₹',
    locale: 'en_IN',
    priceMin: 5000,
    priceMax: 100000,
    priceDivisions: 19,
    searchHint: 'Search Mumbai, Bangalore, Delhi rentals...',
    browsingDesc: 'Checking Indian rental market prices',
    mapCenter: LatLng(19.0760, 72.8777), // Mumbai
    defaultBudgetIndex: 1,  // ₹10k – ₹25k (Popular)
    defaultHouseType: '1BR',
    budgets: [
      BudgetOption(title: 'Under ₹10,000', badge: 'Budget Friendly', desc: 'Affordable PG & 1RK listings', minPrice: 0, maxPrice: 10000),
      BudgetOption(title: '₹10k – ₹25k', badge: 'Popular', desc: 'Standard 1BHK & 2BHK flats', minPrice: 10000, maxPrice: 25000),
      BudgetOption(title: '₹25k – ₹50k', badge: 'Premium', desc: 'Modern 2BHK & 3BHK in prime areas', minPrice: 25000, maxPrice: 50000),
      BudgetOption(title: '₹50,000+', badge: 'Luxury', desc: 'High-end apartments & villas', minPrice: 50000, maxPrice: double.infinity),
    ],
  );

  // Nigeria: Most renters search 2BR self-contain in the ₦150k-500k tier
  static const nigeria = CountryConfig(
    code: 'NG',
    name: 'Nigeria',
    flag: '🇳🇬',
    dialCode: '+234',
    currencyCode: 'NGN',
    currencySymbol: '₦',
    locale: 'en_NG',
    priceMin: 50000,
    priceMax: 2000000,
    priceDivisions: 39,
    searchHint: 'Search Lagos, Abuja, Port Harcourt rentals...',
    browsingDesc: 'Checking Nigerian rental market prices',
    mapCenter: LatLng(6.5244, 3.3792), // Lagos
    defaultBudgetIndex: 1,  // ₦150k – ₦500k (Popular)
    defaultHouseType: '2BR',
    budgets: [
      BudgetOption(title: 'Under ₦150,000', badge: 'Budget Friendly', desc: 'Affordable self-contain & mini flats', minPrice: 0, maxPrice: 150000),
      BudgetOption(title: '₦150k – ₦500k', badge: 'Popular', desc: 'Standard 2 & 3 bedroom flats', minPrice: 150000, maxPrice: 500000),
      BudgetOption(title: '₦500k – ₦1M', badge: 'Premium', desc: 'Modern apartments in prime areas', minPrice: 500000, maxPrice: 1000000),
      BudgetOption(title: '₦1,000,000+', badge: 'Luxury', desc: 'High-end duplexes & serviced apartments', minPrice: 1000000, maxPrice: double.infinity),
    ],
  );

  // US: Most renters search 1BR in the $1k-2k tier
  static const unitedStates = CountryConfig(
    code: 'US',
    name: 'United States',
    flag: '🇺🇸',
    dialCode: '+1',
    currencyCode: 'USD',
    currencySymbol: '\$',
    locale: 'en_US',
    priceMin: 500,
    priceMax: 5000,
    priceDivisions: 18,
    searchHint: 'Search NYC, LA, Chicago rentals...',
    browsingDesc: 'Checking US rental market prices',
    mapCenter: LatLng(40.7128, -74.0060), // New York City
    defaultBudgetIndex: 1,  // $1,000 – $2,000 (Popular)
    defaultHouseType: '1BR',
    budgets: [
      BudgetOption(title: 'Under \$1,000', badge: 'Budget Friendly', desc: 'Affordable studio & shared apartments', minPrice: 0, maxPrice: 1000),
      BudgetOption(title: '\$1,000 – \$2,000', badge: 'Popular', desc: 'Standard 1BR & 2BR apartments', minPrice: 1000, maxPrice: 2000),
      BudgetOption(title: '\$2,000 – \$3,500', badge: 'Premium', desc: 'Modern apartments in prime locations', minPrice: 2000, maxPrice: 3500),
      BudgetOption(title: '\$3,500+', badge: 'Luxury', desc: 'High-end penthouses & luxury rentals', minPrice: 3500, maxPrice: double.infinity),
    ],
  );

  // UK: Most renters search 1-bed flats in the £800-1500 tier
  static const unitedKingdom = CountryConfig(
    code: 'GB',
    name: 'United Kingdom',
    flag: '🇬🇧',
    dialCode: '+44',
    currencyCode: 'GBP',
    currencySymbol: '£',
    locale: 'en_GB',
    priceMin: 400,
    priceMax: 4000,
    priceDivisions: 18,
    searchHint: 'Search London, Manchester, Birmingham rentals...',
    browsingDesc: 'Checking UK rental market prices',
    mapCenter: LatLng(51.5074, -0.1278), // London
    defaultBudgetIndex: 1,  // £800 – £1,500 (Popular)
    defaultHouseType: '1BR',
    budgets: [
      BudgetOption(title: 'Under £800', badge: 'Budget Friendly', desc: 'Affordable studio & shared flats', minPrice: 0, maxPrice: 800),
      BudgetOption(title: '£800 – £1,500', badge: 'Popular', desc: 'Standard 1 & 2 bed flats', minPrice: 800, maxPrice: 1500),
      BudgetOption(title: '£1,500 – £2,500', badge: 'Premium', desc: 'Modern flats in prime areas', minPrice: 1500, maxPrice: 2500),
      BudgetOption(title: '£2,500+', badge: 'Luxury', desc: 'High-end apartments & townhouses', minPrice: 2500, maxPrice: double.infinity),
    ],
  );

  // UAE: Most renters search studio/1BR in the AED 3k-6k tier
  static const uae = CountryConfig(
    code: 'AE',
    name: 'UAE',
    flag: '🇦🇪',
    dialCode: '+971',
    currencyCode: 'AED',
    currencySymbol: 'AED',
    locale: 'en_AE',
    priceMin: 2000,
    priceMax: 20000,
    priceDivisions: 18,
    searchHint: 'Search Dubai, Abu Dhabi, Sharjah rentals...',
    browsingDesc: 'Checking UAE rental market prices',
    mapCenter: LatLng(25.2048, 55.2708), // Dubai
    defaultBudgetIndex: 1,  // AED 3k – 6k (Popular)
    defaultHouseType: 'STUDIO',
    budgets: [
      BudgetOption(title: 'Under AED 3,000', badge: 'Budget Friendly', desc: 'Affordable studio & sharing options', minPrice: 0, maxPrice: 3000),
      BudgetOption(title: 'AED 3k – 6k', badge: 'Popular', desc: 'Standard 1BR & 2BR apartments', minPrice: 3000, maxPrice: 6000),
      BudgetOption(title: 'AED 6k – 12k', badge: 'Premium', desc: 'Modern apartments in prime locations', minPrice: 6000, maxPrice: 12000),
      BudgetOption(title: 'AED 12,000+', badge: 'Luxury', desc: 'High-end villas & penthouses', minPrice: 12000, maxPrice: double.infinity),
    ],
  );

  /// All hand-tuned, fully supported countries (shown in the country picker).
  static const List<CountryConfig> all = [kenya, india, nigeria, unitedStates, unitedKingdom, uae];

  /// Look up by ISO code. Returns a hand-tuned config if the country is in
  /// [all], otherwise generates a localized generic config. Only falls back
  /// to Kenya if the code isn't in the currency lookup at all.
  static CountryConfig fromCode(String code, {LatLng? position}) {
    final upper = code.toUpperCase();
    for (final c in all) {
      if (c.code == upper) return c;
    }
    // Try to generate a generic config for this country
    return generic(upper, position: position);
  }

  /// Generate a reasonable [CountryConfig] for any country using its ISO code
  /// and an optional GPS position for the map center. Budget tiers are derived
  /// from the country's approximate median monthly rent.
  ///
  /// This ensures users in unsupported countries get a localized experience
  /// (correct currency, sensible price ranges) instead of silently defaulting
  /// to Kenya.
  static CountryConfig generic(
    String isoCode, {
    LatLng? position,
    String? countryName,
  }) {
    final upper = isoCode.toUpperCase();
    final info = _currencyByCountry[upper] ?? _currencyByCountry['US']!;

    final median = info.medianRent;
    final sym = info.symbol;
    final shortSym = sym.length <= 1 ? sym : '$sym ';
    final name = countryName ?? info.name;

    // Generate 4 budget tiers from the median monthly rent:
    //   Budget:  0 → 0.6× median
    //   Popular: 0.6× → 1.5× median
    //   Premium: 1.5× → 3× median
    //   Luxury:  3× median+
    final t1 = (median * 0.6).roundToDouble();
    final t2 = (median * 1.5).roundToDouble();
    final t3 = (median * 3.0).roundToDouble();

    return CountryConfig(
      code: upper,
      name: name,
      flag: _isoToFlag(upper),
      dialCode: info.dialCode,
      currencyCode: info.code,
      currencySymbol: sym,
      locale: info.locale,
      priceMin: 0,
      priceMax: t3 * 1.5,
      priceDivisions: 20,
      searchHint: 'Search rentals in $name...',
      browsingDesc: 'Checking $name rental market prices',
      mapCenter: position ?? const LatLng(0, 0),
      budgets: [
        BudgetOption(
          title: 'Under $shortSym${_compact(t1)}',
          badge: 'Budget Friendly',
          desc: 'Affordable rental listings',
          minPrice: 0,
          maxPrice: t1,
        ),
        BudgetOption(
          title: '$shortSym${_compact(t1)} – $shortSym${_compact(t2)}',
          badge: 'Popular',
          desc: 'Standard apartments in good areas',
          minPrice: t1,
          maxPrice: t2,
        ),
        BudgetOption(
          title: '$shortSym${_compact(t2)} – $shortSym${_compact(t3)}',
          badge: 'Premium',
          desc: 'Modern homes in prime locations',
          minPrice: t2,
          maxPrice: t3,
        ),
        BudgetOption(
          title: '$shortSym${_compact(t3)}+',
          badge: 'Luxury',
          desc: 'High-end apartments & villas',
          minPrice: t3,
          maxPrice: double.infinity,
        ),
      ],
    );
  }

  /// Whether this config was auto-generated (not in the hand-tuned [all] list).
  bool get isGeneric => !all.any((c) => c.code == code);

  /// Convert a number to compact display: 1500 → "1.5k", 25000 → "25k"
  static String _compact(double n) {
    if (n >= 1000000) {
      final m = n / 1000000;
      return m == m.roundToDouble() ? '${m.round()}M' : '${m.toStringAsFixed(1)}M';
    }
    if (n >= 1000) {
      final k = n / 1000;
      return k == k.roundToDouble() ? '${k.round()}k' : '${k.toStringAsFixed(1)}k';
    }
    return n.round().toString();
  }

  /// Convert ISO 3166-1 alpha-2 to emoji flag (e.g. 'ZA' → '🇿🇦')
  static String _isoToFlag(String code) {
    final upper = code.toUpperCase();
    if (upper.length != 2) return '🏳️';
    final a = 0x1F1E6 - 0x41; // Regional indicator offset
    return String.fromCharCodes([upper.codeUnitAt(0) + a, upper.codeUnitAt(1) + a]);
  }
}

// ─── Currency Lookup ───────────────────────────────────────────────────────

/// Compact currency info for generating generic [CountryConfig]s.
class CurrencyInfo {
  final String name;       // Country name
  final String code;       // ISO 4217 currency code
  final String symbol;     // Display symbol
  final String locale;     // Dart/ICU locale
  final String dialCode;   // International dialing prefix
  final double medianRent; // Approximate median monthly rent in local currency

  const CurrencyInfo(this.name, this.code, this.symbol, this.locale, this.dialCode, this.medianRent);
}

/// Lookup table mapping ISO 3166-1 alpha-2 codes to currency data.
/// Covers 50+ countries across Africa, Asia, Europe, Americas, and Oceania.
/// Median rents are approximate urban figures for a standard 1BR apartment.
const _currencyByCountry = <String, CurrencyInfo>{
  // ─── Africa ────────────────────────────────────────────────────
  'ZA': CurrencyInfo('South Africa', 'ZAR', 'R', 'en_ZA', '+27', 8000),
  'GH': CurrencyInfo('Ghana', 'GHS', 'GH₵', 'en_GH', '+233', 2500),
  'TZ': CurrencyInfo('Tanzania', 'TZS', 'TSh', 'en_TZ', '+255', 400000),
  'UG': CurrencyInfo('Uganda', 'UGX', 'USh', 'en_UG', '+256', 800000),
  'RW': CurrencyInfo('Rwanda', 'RWF', 'FRw', 'en_RW', '+250', 200000),
  'ET': CurrencyInfo('Ethiopia', 'ETB', 'Br', 'en_ET', '+251', 15000),
  'EG': CurrencyInfo('Egypt', 'EGP', 'E£', 'ar_EG', '+20', 8000),
  'MA': CurrencyInfo('Morocco', 'MAD', 'MAD', 'fr_MA', '+212', 5000),
  'TN': CurrencyInfo('Tunisia', 'TND', 'DT', 'fr_TN', '+216', 800),
  'SN': CurrencyInfo('Senegal', 'XOF', 'CFA', 'fr_SN', '+221', 150000),
  'CI': CurrencyInfo('Ivory Coast', 'XOF', 'CFA', 'fr_CI', '+225', 120000),
  'CM': CurrencyInfo('Cameroon', 'XAF', 'FCFA', 'fr_CM', '+237', 80000),
  'CD': CurrencyInfo('DR Congo', 'CDF', 'FC', 'fr_CD', '+243', 500000),
  'ZW': CurrencyInfo('Zimbabwe', 'USD', '\$', 'en_ZW', '+263', 400),
  'MZ': CurrencyInfo('Mozambique', 'MZN', 'MT', 'pt_MZ', '+258', 15000),
  'AO': CurrencyInfo('Angola', 'AOA', 'Kz', 'pt_AO', '+244', 200000),
  'ZM': CurrencyInfo('Zambia', 'ZMW', 'ZK', 'en_ZM', '+260', 5000),
  'BW': CurrencyInfo('Botswana', 'BWP', 'P', 'en_BW', '+267', 5000),
  'MU': CurrencyInfo('Mauritius', 'MUR', 'Rs', 'en_MU', '+230', 20000),

  // ─── Asia ──────────────────────────────────────────────────────
  'PK': CurrencyInfo('Pakistan', 'PKR', 'Rs', 'en_PK', '+92', 40000),
  'BD': CurrencyInfo('Bangladesh', 'BDT', '৳', 'bn_BD', '+880', 20000),
  'LK': CurrencyInfo('Sri Lanka', 'LKR', 'Rs', 'en_LK', '+94', 50000),
  'NP': CurrencyInfo('Nepal', 'NPR', 'Rs', 'ne_NP', '+977', 25000),
  'PH': CurrencyInfo('Philippines', 'PHP', '₱', 'en_PH', '+63', 15000),
  'ID': CurrencyInfo('Indonesia', 'IDR', 'Rp', 'id_ID', '+62', 4000000),
  'MY': CurrencyInfo('Malaysia', 'MYR', 'RM', 'ms_MY', '+60', 1800),
  'TH': CurrencyInfo('Thailand', 'THB', '฿', 'th_TH', '+66', 15000),
  'VN': CurrencyInfo('Vietnam', 'VND', '₫', 'vi_VN', '+84', 8000000),
  'KR': CurrencyInfo('South Korea', 'KRW', '₩', 'ko_KR', '+82', 800000),
  'JP': CurrencyInfo('Japan', 'JPY', '¥', 'ja_JP', '+81', 80000),
  'CN': CurrencyInfo('China', 'CNY', '¥', 'zh_CN', '+86', 5000),
  'SG': CurrencyInfo('Singapore', 'SGD', 'S\$', 'en_SG', '+65', 2500),
  'HK': CurrencyInfo('Hong Kong', 'HKD', 'HK\$', 'zh_HK', '+852', 15000),
  'TW': CurrencyInfo('Taiwan', 'TWD', 'NT\$', 'zh_TW', '+886', 15000),
  'KH': CurrencyInfo('Cambodia', 'USD', '\$', 'km_KH', '+855', 400),
  'MM': CurrencyInfo('Myanmar', 'MMK', 'K', 'my_MM', '+95', 400000),

  // ─── Middle East ───────────────────────────────────────────────
  'SA': CurrencyInfo('Saudi Arabia', 'SAR', 'SAR', 'ar_SA', '+966', 3000),
  'QA': CurrencyInfo('Qatar', 'QAR', 'QR', 'ar_QA', '+974', 5000),
  'KW': CurrencyInfo('Kuwait', 'KWD', 'KD', 'ar_KW', '+965', 350),
  'BH': CurrencyInfo('Bahrain', 'BHD', 'BD', 'ar_BH', '+973', 300),
  'OM': CurrencyInfo('Oman', 'OMR', 'OMR', 'ar_OM', '+968', 300),
  'JO': CurrencyInfo('Jordan', 'JOD', 'JD', 'ar_JO', '+962', 350),
  'LB': CurrencyInfo('Lebanon', 'USD', '\$', 'ar_LB', '+961', 600),
  'IQ': CurrencyInfo('Iraq', 'IQD', 'IQD', 'ar_IQ', '+964', 500000),
  'IL': CurrencyInfo('Israel', 'ILS', '₪', 'he_IL', '+972', 5000),
  'TR': CurrencyInfo('Turkey', 'TRY', '₺', 'tr_TR', '+90', 15000),

  // ─── Europe ────────────────────────────────────────────────────
  'DE': CurrencyInfo('Germany', 'EUR', '€', 'de_DE', '+49', 1200),
  'FR': CurrencyInfo('France', 'EUR', '€', 'fr_FR', '+33', 1100),
  'ES': CurrencyInfo('Spain', 'EUR', '€', 'es_ES', '+34', 900),
  'IT': CurrencyInfo('Italy', 'EUR', '€', 'it_IT', '+39', 900),
  'PT': CurrencyInfo('Portugal', 'EUR', '€', 'pt_PT', '+351', 800),
  'NL': CurrencyInfo('Netherlands', 'EUR', '€', 'nl_NL', '+31', 1400),
  'BE': CurrencyInfo('Belgium', 'EUR', '€', 'nl_BE', '+32', 1000),
  'AT': CurrencyInfo('Austria', 'EUR', '€', 'de_AT', '+43', 1000),
  'IE': CurrencyInfo('Ireland', 'EUR', '€', 'en_IE', '+353', 1800),
  'GR': CurrencyInfo('Greece', 'EUR', '€', 'el_GR', '+30', 600),
  'FI': CurrencyInfo('Finland', 'EUR', '€', 'fi_FI', '+358', 1000),
  'SE': CurrencyInfo('Sweden', 'SEK', 'kr', 'sv_SE', '+46', 12000),
  'NO': CurrencyInfo('Norway', 'NOK', 'kr', 'nb_NO', '+47', 14000),
  'DK': CurrencyInfo('Denmark', 'DKK', 'kr', 'da_DK', '+45', 10000),
  'CH': CurrencyInfo('Switzerland', 'CHF', 'CHF', 'de_CH', '+41', 2000),
  'PL': CurrencyInfo('Poland', 'PLN', 'zł', 'pl_PL', '+48', 3500),
  'CZ': CurrencyInfo('Czechia', 'CZK', 'Kč', 'cs_CZ', '+420', 20000),
  'RO': CurrencyInfo('Romania', 'RON', 'lei', 'ro_RO', '+40', 2500),
  'HU': CurrencyInfo('Hungary', 'HUF', 'Ft', 'hu_HU', '+36', 250000),
  'UA': CurrencyInfo('Ukraine', 'UAH', '₴', 'uk_UA', '+380', 15000),
  'RU': CurrencyInfo('Russia', 'RUB', '₽', 'ru_RU', '+7', 40000),

  // ─── Americas ──────────────────────────────────────────────────
  'CA': CurrencyInfo('Canada', 'CAD', 'CA\$', 'en_CA', '+1', 2000),
  'MX': CurrencyInfo('Mexico', 'MXN', 'MX\$', 'es_MX', '+52', 12000),
  'BR': CurrencyInfo('Brazil', 'BRL', 'R\$', 'pt_BR', '+55', 2500),
  'AR': CurrencyInfo('Argentina', 'ARS', 'AR\$', 'es_AR', '+54', 400000),
  'CO': CurrencyInfo('Colombia', 'COP', 'COL\$', 'es_CO', '+57', 1500000),
  'CL': CurrencyInfo('Chile', 'CLP', 'CLP', 'es_CL', '+56', 500000),
  'PE': CurrencyInfo('Peru', 'PEN', 'S/', 'es_PE', '+51', 1500),
  'EC': CurrencyInfo('Ecuador', 'USD', '\$', 'es_EC', '+593', 500),
  'UY': CurrencyInfo('Uruguay', 'UYU', '\$U', 'es_UY', '+598', 25000),
  'CR': CurrencyInfo('Costa Rica', 'CRC', '₡', 'es_CR', '+506', 350000),
  'PA': CurrencyInfo('Panama', 'USD', '\$', 'es_PA', '+507', 800),
  'DO': CurrencyInfo('Dominican Republic', 'DOP', 'RD\$', 'es_DO', '+1', 25000),
  'JM': CurrencyInfo('Jamaica', 'JMD', 'J\$', 'en_JM', '+1', 60000),
  'TT': CurrencyInfo('Trinidad & Tobago', 'TTD', 'TT\$', 'en_TT', '+1', 5000),

  // ─── Oceania ───────────────────────────────────────────────────
  'AU': CurrencyInfo('Australia', 'AUD', 'A\$', 'en_AU', '+61', 2200),
  'NZ': CurrencyInfo('New Zealand', 'NZD', 'NZ\$', 'en_NZ', '+64', 2000),
  'FJ': CurrencyInfo('Fiji', 'FJD', 'FJ\$', 'en_FJ', '+679', 1500),

  // ─── Fallback (USD) ────────────────────────────────────────────
  'US': CurrencyInfo('United States', 'USD', '\$', 'en_US', '+1', 1500),
};
