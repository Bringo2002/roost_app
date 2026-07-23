/// Budget tier shown during onboarding.
class BudgetOption {
  final String title;
  final String badge;
  final String desc;

  const BudgetOption({
    required this.title,
    required this.badge,
    required this.desc,
  });
}

/// All region-specific configuration for a supported country.
class CountryConfig {
  final String code;           // ISO 3166-1 alpha-2: 'KE', 'IN', 'NG', etc.
  final String name;           // 'Kenya', 'India', etc.
  final String flag;           // Emoji flag: '🇰🇪', '🇮🇳'
  final String currencyCode;   // ISO 4217: 'KES', 'INR', 'NGN'
  final String currencySymbol; // Display symbol: 'KES', '₹', '₦', '$'
  final String locale;         // Dart/ICU locale for number formatting: 'en_KE', 'en_IN'
  final double priceMin;       // Filter slider minimum
  final double priceMax;       // Filter slider maximum
  final int priceDivisions;    // Slider divisions
  final String searchHint;     // Placeholder in search bar
  final List<BudgetOption> budgets; // Onboarding budget tiers
  final String browsingDesc;   // "Just Browsing" description text
  final String paymentLabel;   // "M-Pesa Receipt" / "UPI Reference" / "Payment Reference"
  final double holdingFee;     // Holding fee amount in local currency

  const CountryConfig({
    required this.code,
    required this.name,
    required this.flag,
    required this.currencyCode,
    required this.currencySymbol,
    required this.locale,
    required this.priceMin,
    required this.priceMax,
    required this.priceDivisions,
    required this.searchHint,
    required this.budgets,
    required this.browsingDesc,
    required this.paymentLabel,
    required this.holdingFee,
  });

  // ── Supported Countries ───────────────────────────────────────────

  static const kenya = CountryConfig(
    code: 'KE',
    name: 'Kenya',
    flag: '🇰🇪',
    currencyCode: 'KES',
    currencySymbol: 'KES',
    locale: 'en_KE',
    priceMin: 5000,
    priceMax: 150000,
    priceDivisions: 29,
    searchHint: 'Search Nairobi rentals, Kilimani, Westlands...',
    browsingDesc: 'Checking Nairobi market prices',
    paymentLabel: 'M-Pesa Receipt',
    holdingFee: 2000,
    budgets: [
      BudgetOption(title: 'Under KES 15,000', badge: 'Budget Friendly', desc: 'Affordable studio & bedsitter listings'),
      BudgetOption(title: 'KES 15k – 30k', badge: 'Popular', desc: 'Standard 1BR & 2BR apartments'),
      BudgetOption(title: 'KES 30k – 60k', badge: 'Premium', desc: 'Modern 2BR & 3BR in prime areas'),
      BudgetOption(title: 'KES 60,000+', badge: 'Luxury', desc: 'High-end penthouses & serviced units'),
    ],
  );

  static const india = CountryConfig(
    code: 'IN',
    name: 'India',
    flag: '🇮🇳',
    currencyCode: 'INR',
    currencySymbol: '₹',
    locale: 'en_IN',
    priceMin: 5000,
    priceMax: 100000,
    priceDivisions: 19,
    searchHint: 'Search Mumbai, Bangalore, Delhi rentals...',
    browsingDesc: 'Checking Indian rental market prices',
    paymentLabel: 'UPI Reference',
    holdingFee: 500,
    budgets: [
      BudgetOption(title: 'Under ₹10,000', badge: 'Budget Friendly', desc: 'Affordable PG & 1RK listings'),
      BudgetOption(title: '₹10k – ₹25k', badge: 'Popular', desc: 'Standard 1BHK & 2BHK flats'),
      BudgetOption(title: '₹25k – ₹50k', badge: 'Premium', desc: 'Modern 2BHK & 3BHK in prime areas'),
      BudgetOption(title: '₹50,000+', badge: 'Luxury', desc: 'High-end apartments & villas'),
    ],
  );

  static const nigeria = CountryConfig(
    code: 'NG',
    name: 'Nigeria',
    flag: '🇳🇬',
    currencyCode: 'NGN',
    currencySymbol: '₦',
    locale: 'en_NG',
    priceMin: 50000,
    priceMax: 2000000,
    priceDivisions: 39,
    searchHint: 'Search Lagos, Abuja, Port Harcourt rentals...',
    browsingDesc: 'Checking Nigerian rental market prices',
    paymentLabel: 'Bank Transfer Reference',
    holdingFee: 5000,
    budgets: [
      BudgetOption(title: 'Under ₦150,000', badge: 'Budget Friendly', desc: 'Affordable self-contain & mini flats'),
      BudgetOption(title: '₦150k – ₦500k', badge: 'Popular', desc: 'Standard 2 & 3 bedroom flats'),
      BudgetOption(title: '₦500k – ₦1M', badge: 'Premium', desc: 'Modern apartments in prime areas'),
      BudgetOption(title: '₦1,000,000+', badge: 'Luxury', desc: 'High-end duplexes & serviced apartments'),
    ],
  );

  static const unitedStates = CountryConfig(
    code: 'US',
    name: 'United States',
    flag: '🇺🇸',
    currencyCode: 'USD',
    currencySymbol: '\$',
    locale: 'en_US',
    priceMin: 500,
    priceMax: 5000,
    priceDivisions: 18,
    searchHint: 'Search NYC, LA, Chicago rentals...',
    browsingDesc: 'Checking US rental market prices',
    paymentLabel: 'Payment Reference',
    holdingFee: 200,
    budgets: [
      BudgetOption(title: 'Under \$1,000', badge: 'Budget Friendly', desc: 'Affordable studio & shared apartments'),
      BudgetOption(title: '\$1,000 – \$2,000', badge: 'Popular', desc: 'Standard 1BR & 2BR apartments'),
      BudgetOption(title: '\$2,000 – \$3,500', badge: 'Premium', desc: 'Modern apartments in prime locations'),
      BudgetOption(title: '\$3,500+', badge: 'Luxury', desc: 'High-end penthouses & luxury rentals'),
    ],
  );

  static const unitedKingdom = CountryConfig(
    code: 'GB',
    name: 'United Kingdom',
    flag: '🇬🇧',
    currencyCode: 'GBP',
    currencySymbol: '£',
    locale: 'en_GB',
    priceMin: 400,
    priceMax: 4000,
    priceDivisions: 18,
    searchHint: 'Search London, Manchester, Birmingham rentals...',
    browsingDesc: 'Checking UK rental market prices',
    paymentLabel: 'Payment Reference',
    holdingFee: 150,
    budgets: [
      BudgetOption(title: 'Under £800', badge: 'Budget Friendly', desc: 'Affordable studio & shared flats'),
      BudgetOption(title: '£800 – £1,500', badge: 'Popular', desc: 'Standard 1 & 2 bed flats'),
      BudgetOption(title: '£1,500 – £2,500', badge: 'Premium', desc: 'Modern flats in prime areas'),
      BudgetOption(title: '£2,500+', badge: 'Luxury', desc: 'High-end apartments & townhouses'),
    ],
  );

  static const uae = CountryConfig(
    code: 'AE',
    name: 'UAE',
    flag: '🇦🇪',
    currencyCode: 'AED',
    currencySymbol: 'AED',
    locale: 'en_AE',
    priceMin: 2000,
    priceMax: 20000,
    priceDivisions: 18,
    searchHint: 'Search Dubai, Abu Dhabi, Sharjah rentals...',
    browsingDesc: 'Checking UAE rental market prices',
    paymentLabel: 'Payment Reference',
    holdingFee: 500,
    budgets: [
      BudgetOption(title: 'Under AED 3,000', badge: 'Budget Friendly', desc: 'Affordable studio & sharing options'),
      BudgetOption(title: 'AED 3k – 6k', badge: 'Popular', desc: 'Standard 1BR & 2BR apartments'),
      BudgetOption(title: 'AED 6k – 12k', badge: 'Premium', desc: 'Modern apartments in prime locations'),
      BudgetOption(title: 'AED 12,000+', badge: 'Luxury', desc: 'High-end villas & penthouses'),
    ],
  );

  /// All supported countries, ordered for display.
  static const List<CountryConfig> all = [kenya, india, nigeria, unitedStates, unitedKingdom, uae];

  /// Look up by ISO code, defaulting to Kenya.
  static CountryConfig fromCode(String code) {
    return all.firstWhere((c) => c.code == code, orElse: () => kenya);
  }
}
