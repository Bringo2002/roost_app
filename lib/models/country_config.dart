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

  /// All supported countries, ordered for display.
  static const List<CountryConfig> all = [kenya, india, nigeria, unitedStates, unitedKingdom, uae];

  /// Look up by ISO code, defaulting to Kenya.
  static CountryConfig fromCode(String code) {
    return all.firstWhere((c) => c.code == code, orElse: () => kenya);
  }
}
