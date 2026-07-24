import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:roost_app/models/country_config.dart';

/// Singleton service that manages the user's selected country and provides
/// locale-aware currency formatting throughout the app.
class CountryService {
  CountryService._();
  static final CountryService _instance = CountryService._();
  static CountryService get instance => _instance;

  static const _prefKey = 'selected_country';

  CountryConfig _current = CountryConfig.kenya;

  /// The active country configuration.
  CountryConfig get current => _current;

  /// Whether a country has been explicitly selected (vs. default).
  bool get hasSelection => _hasSelection;
  bool _hasSelection = false;

  /// Initialize from SharedPreferences. Call once at app startup.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefKey);
    if (code != null) {
      _current = CountryConfig.fromCode(code);
      _hasSelection = true;
    }
  }

  /// Auto-detect the user's country from GPS location.
  /// Returns the detected [CountryConfig], or `null` if detection fails
  /// (permissions denied, location off, unsupported country, etc.).
  Future<CountryConfig?> autoDetectCountry() async {
    try {
      // Check / request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      // Get current position (fast, low accuracy is fine for country detection)
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );

      // Reverse geocode to get country ISO code
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) return null;

      final isoCode = placemarks.first.isoCountryCode; // e.g. 'KE', 'IN'
      if (isoCode == null || isoCode.isEmpty) return null;

      // Match against supported countries
      final match = CountryConfig.all.where(
        (c) => c.code.toUpperCase() == isoCode.toUpperCase(),
      );

      if (match.isEmpty) return null;

      return match.first;
    } catch (_) {
      return null;
    }
  }

  /// Auto-detect and persist the country in one call.
  /// Returns the detected config or null on failure.
  Future<CountryConfig?> autoDetectAndSet() async {
    final detected = await autoDetectCountry();
    if (detected != null) {
      await setCountry(detected);
    }
    return detected;
  }

  /// Set the active country and persist the choice.
  Future<void> setCountry(CountryConfig config) async {
    _current = config;
    _hasSelection = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, config.code);
  }

  // ── Formatting Helpers ──────────────────────────────────────────

  /// Format a price with locale-aware grouping and currency symbol.
  /// Examples:
  ///   Kenya  → "KES 25,000"
  ///   India  → "₹25,000"   (uses Indian lakh grouping via en_IN)
  ///   US     → "$2,500"
  String formatPrice(num amount) {
    final symbol = _current.currencySymbol;
    final separator = (symbol.length > 1 && !symbol.endsWith(' ')) ? ' ' : '';
    final numberPart = NumberFormat('#,##0', _current.locale).format(amount);
    return '$symbol$separator$numberPart';
  }

  /// Format price with a period suffix, e.g. "KES 25,000/mo"
  String formatPriceWithPeriod(num amount, {String period = 'mo'}) {
    return '${formatPrice(amount)}/$period';
  }

  /// Format just the number (no symbol), locale-aware.
  String formatNumber(num amount) {
    final formatter = NumberFormat('#,##0', _current.locale);
    return formatter.format(amount);
  }

  /// The currency symbol for the current country.
  String get currencySymbol => _current.currencySymbol;

  /// The currency code for the current country (e.g. 'KES', 'INR').
  String get currencyCode => _current.currencyCode;

  // ── Static convenience accessors ────────────────────────────────

  /// Shorthand: `CountryService.config` instead of `CountryService.instance.current`
  static CountryConfig get config => _instance._current;

  /// Shorthand: `CountryService.price(25000)` → "KES 25,000"
  static String price(num amount) => _instance.formatPrice(amount);

  /// Shorthand: `CountryService.pricePerMonth(25000)` → "KES 25,000/mo"
  static String pricePerMonth(num amount) => _instance.formatPriceWithPeriod(amount);
}
