import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/country_service.dart';
import 'package:roost_app/services/location_service.dart';
import 'package:roost_app/widgets/property/property_card.dart';

/// Friendly display labels for the canonical backend house-type values,
/// so filter chips read naturally instead of showing raw codes like
/// 'BEDSITTER' or '1BR' -- matching still happens on the canonical value.
const Map<String, String> _houseTypeLabels = {
  'All': 'All',
  'BEDSITTER': 'Bedsitter',
  'STUDIO': 'Studio',
  '1BR': '1 Bedroom',
  '2BR': '2 Bedroom',
  '3BR+': '3 Bedroom+',
};

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  List<Property> _allProperties = [];
  List<Property> _results = [];
  bool _loading = true;
  bool _loadError = false;

  final _searchCtrl = TextEditingController();

  // Active Filter state
  String _houseType = 'All';
  int _bedrooms = 0;
  late RangeValues _priceRange;

  bool _furnished = false;
  bool _parking = false;
  bool _wifi = false;
  bool _water = false;
  bool _security = false;
  bool _balcony = false;
  bool _petFriendly = false;
  bool _verifiedOnly = false;
  bool _sortNewestFirst = false;

  Position? _userPosition;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    final config = CountryService.config;
    _priceRange = RangeValues(config.priceMin, config.priceMax);
    _loadProperties();
    _loadUserLocation();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), _applyClientSideFilters);
  }

  Future<void> _loadUserLocation() async {
    final position = await LocationService.getCurrentPosition();
    if (!mounted || position == null) return;
    setState(() {
      _userPosition = position;
    });
    _applyClientSideFilters();
  }

  /// Distance from the user to [p] in km, or null if either the user's
  /// location or the property's coordinates are unknown. Never falls back
  /// to a default coordinate -- an unknown distance stays unknown rather
  /// than being sorted as if the property were at (0, 0).
  double? _distanceKmTo(Property p) {
    final pos = _userPosition;
    final lat = p.latitude;
    final lng = p.longitude;
    if (pos == null || lat == null || lng == null) return null;
    return LocationService.distanceKm(pos.latitude, pos.longitude, lat, lng);
  }

  Future<void> _loadProperties() async {
    await _fetchFiltered();
  }

  /// Builds the query string for GET /api/properties/filter from the
  /// filter sheet's own state. Deliberately does NOT include anything
  /// parsed from free-text search (_parseSearchIntent) -- the backend has
  /// no NLP matching, so that stays a client-side pass over whatever this
  /// returns, exactly as before. This still captures the common case
  /// (narrowing via the filter sheet) without the full table download.
  String _buildFilterQuery() {
    final params = <String, String>{};

    // '3BR+' isn't a literal value in the houseType column -- it means
    // "3 or more bedrooms", which is exactly what the bedrooms param's
    // >= semantics already express, so it's folded into the bedrooms
    // floor instead of sent as `type` (which does an exact string match
    // and would incorrectly exclude a stored, say, "4BR").
    if (_houseType == '3BR+') {
      final floor = _bedrooms > 3 ? _bedrooms : 3;
      params['bedrooms'] = '$floor';
    } else {
      if (_houseType != 'All') params['type'] = _houseType;
      if (_bedrooms > 0) params['bedrooms'] = '$_bedrooms';
    }

    final config = CountryService.config;
    if (_priceRange.start > config.priceMin) params['minPrice'] = '${_priceRange.start}';
    if (_priceRange.end < config.priceMax) params['maxPrice'] = '${_priceRange.end}';

    if (_furnished) params['furnished'] = 'true';
    if (_parking) params['parking'] = 'true';
    if (_wifi) params['wifi'] = 'true';
    if (_water) params['water'] = 'true';
    if (_security) params['security'] = 'true';
    if (_verifiedOnly) params['verified'] = 'true';

    return params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
  }

  /// Fetches from the server with the filter sheet's constraints already
  /// applied, then runs the remaining client-only pass (free-text NLP
  /// matching, balcony/petFriendly, sorting) on the smaller result set.
  Future<void> _fetchFiltered() async {
    setState(() => _loadError = false);
    try {
      final query = _buildFilterQuery();
      final path = query.isEmpty ? '/api/properties/filter' : '/api/properties/filter?$query';
      final jsonList = await ApiService.get(path);
      final props = (jsonList as List).map((j) => Property.fromJson(j)).toList();

      if (!mounted) return;
      setState(() {
        _allProperties = props;
        _loading = false;
      });
      _applyClientSideFilters();
    } catch (_) {
      if (mounted) setState(() {
        _loading = false;
        _loadError = true;
      });
    }
  }

  /// Parses common natural-language patterns out of the search box so
  /// queries like "Studio under 20k" or "2 bedroom Kilimani" work, per
  /// the product brief's stated examples -- not just literal keyword
  /// matching. Recognized tokens are stripped from the query before the
  /// remainder is used for a plain substring match on title/location.
  /// Whatever this parses out applies as an ADDITIONAL constraint
  /// alongside the filter sheet, not a replacement for it.
  ({String remainingText, double? maxPrice, String? houseType, bool furnished}) _parseSearchIntent(String query) {
    String text = ' ${query.toLowerCase()} ';
    double? maxPrice;
    String? houseType;
    bool furnished = false;

    // "under/below/less than 20k" -- 'k' suffix means thousands.
    final priceMatch = RegExp(r'\b(?:under|below|less than)\s+(\d+)(k)?\b').firstMatch(text);
    if (priceMatch != null) {
      final n = double.tryParse(priceMatch.group(1)!);
      if (n != null) {
        maxPrice = priceMatch.group(2) != null ? n * 1000 : n;
        text = text.replaceRange(priceMatch.start, priceMatch.end, ' ');
      }
    }

    // House type keywords -- first match wins, matching the canonical
    // backend format (BEDSITTER/STUDIO/1BR/2BR/3BR+).
    const typeKeywords = {
      'bedsitter': 'BEDSITTER',
      'studio': 'STUDIO',
      'one bedroom': '1BR', '1 bedroom': '1BR', '1br': '1BR',
      'two bedroom': '2BR', '2 bedroom': '2BR', '2br': '2BR',
      'three bedroom': '3BR+', '3 bedroom': '3BR+', '3br': '3BR+',
    };
    for (final entry in typeKeywords.entries) {
      if (text.contains(entry.key)) {
        houseType = entry.value;
        text = text.replaceFirst(entry.key, ' ');
        break;
      }
    }

    if (text.contains('furnished')) {
      furnished = true;
      text = text.replaceFirst('furnished', ' ');
    }

    // Filler words that add no match value once the constraint above
    // them has already been extracted (e.g. "near Strathmore" should
    // just match "Strathmore" against location).
    for (final filler in ['near', 'in', 'at', 'around']) {
      text = text.replaceAll(RegExp('\\b$filler\\b'), ' ');
    }

    return (
      remainingText: text.trim().replaceAll(RegExp(r'\s+'), ' '),
      maxPrice: maxPrice,
      houseType: houseType,
      furnished: furnished,
    );
  }

  /// Client-only pass over the already server-filtered [_allProperties]:
  /// free-text NLP matching (the backend has no text search), balcony and
  /// pet-friendly (not supported by /api/properties/filter), and sorting
  /// (the backend doesn't sort). Everything else -- house type, bedrooms,
  /// price, furnished/parking/wifi/water/security, verified -- was already
  /// applied server-side by _fetchFiltered before this runs.
  void _applyClientSideFilters() {
    final intent = _parseSearchIntent(_searchCtrl.text.trim());
    final query = intent.remainingText;
    setState(() {
      _results = _allProperties.where((p) {
        final matchesQuery = query.isEmpty ||
            p.title.toLowerCase().contains(query) ||
            p.location.toLowerCase().contains(query) ||
            p.houseType.toLowerCase().contains(query);

        // House type/price/furnished parsed from the search text itself
        // (e.g. "Studio under 20k") -- additional constraints on top of
        // whatever the filter sheet already narrowed server-side, not a
        // replacement for it.
        final matchesIntentHouseType = intent.houseType == null ||
            p.houseType.toUpperCase() == intent.houseType ||
            (intent.houseType == '3BR+' && p.bedrooms >= 3);
        final matchesIntentPrice = intent.maxPrice == null || p.price <= intent.maxPrice!;
        final matchesIntentFurnished = !intent.furnished || p.furnished;

        final matchesBalcony = !_balcony || p.balcony;
        final matchesPetFriendly = !_petFriendly || p.petFriendly;

        return matchesQuery &&
            matchesIntentHouseType &&
            matchesIntentPrice &&
            matchesIntentFurnished &&
            matchesBalcony &&
            matchesPetFriendly;
      }).toList();

      _sortResults();
    });
  }

  void _sortResults() {
    if (_sortNewestFirst) {
      _results.sort((a, b) {
        final dateA = DateTime.tryParse(a.listedAt ?? '');
        final dateB = DateTime.tryParse(b.listedAt ?? '');
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA); // newest first
      });
    } else if (_userPosition != null) {
      _results.sort((a, b) {
        final distA = _distanceKmTo(a) ?? double.infinity;
        final distB = _distanceKmTo(b) ?? double.infinity;
        return distA.compareTo(distB);
      });
    }
  }

  /// Resets all filters to their defaults, deriving the price range from
  /// the current country's actual configured bounds rather than a
  /// hardcoded range that only made sense for one currency.
  void _resetFilters() {
    setState(() {
      _houseType = 'All';
      _bedrooms = 0;
      _priceRange = RangeValues(CountryService.config.priceMin, CountryService.config.priceMax);
      _furnished = false;
      _parking = false;
      _wifi = false;
      _water = false;
      _security = false;
      _balcony = false;
      _petFriendly = false;
      _verifiedOnly = false;
      _sortNewestFirst = false;
    });
    _fetchFiltered();
  }

  /// Number of filters currently set away from their defaults. Drives the
  /// badge on the filter button so it's clear at a glance whether a
  /// search is being narrowed, even after the sheet is closed.
  int get _activeFilterCount {
    final config = CountryService.config;
    int count = 0;
    if (_houseType != 'All') count++;
    if (_bedrooms != 0) count++;
    if (_priceRange.start != config.priceMin || _priceRange.end != config.priceMax) count++;
    if (_furnished) count++;
    if (_parking) count++;
    if (_wifi) count++;
    if (_water) count++;
    if (_security) count++;
    if (_balcony) count++;
    if (_petFriendly) count++;
    if (_verifiedOnly) count++;
    if (_sortNewestFirst) count++;
    return count;
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 40),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filter Rentals',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () {
                            _resetFilters();
                            setSheetState(() {});
                          },
                          child: const Text('Reset', style: TextStyle(color: Colors.grey)),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF2C2C2E)),
                    const SizedBox(height: 12),

                    // House Type
                    const Text('House Type', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['All', 'BEDSITTER', 'STUDIO', '1BR', '2BR', '3BR+'].map((type) {
                          final selected = _houseType == type;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                _houseTypeLabels[type] ?? type,
                                style: TextStyle(
                                  color: selected ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              selected: selected,
                              selectedColor: Colors.white,
                              backgroundColor: Colors.black,
                              onSelected: (_) => setSheetState(() => _houseType = type),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Bedrooms
                    const Text('Bedrooms', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      children: [0, 1, 2, 3, 4].map((count) {
                        final selected = _bedrooms == count;
                        final label = count == 0 ? 'Any' : '$count+';
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              label,
                              style: TextStyle(
                                color: selected ? Colors.black : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            selected: selected,
                            selectedColor: Colors.white,
                            backgroundColor: Colors.black,
                            onSelected: (_) => setSheetState(() => _bedrooms = count),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // Price Range
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Price Range', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                        Text(
                          '${CountryService.price(_priceRange.start)} - ${CountryService.price(_priceRange.end)}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    RangeSlider(
                      values: _priceRange,
                      min: CountryService.config.priceMin,
                      max: CountryService.config.priceMax,
                      divisions: CountryService.config.priceDivisions,
                      activeColor: Colors.white,
                      inactiveColor: Colors.grey[800],
                      onChanged: (vals) => setSheetState(() => _priceRange = vals),
                    ),

                    const SizedBox(height: 16),

                    // Amenities
                    const Text('Amenities', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('Furnished'),
                          selected: _furnished,
                          selectedColor: Colors.white,
                          onSelected: (val) => setSheetState(() => _furnished = val),
                        ),
                        FilterChip(
                          label: const Text('Parking'),
                          selected: _parking,
                          selectedColor: Colors.white,
                          onSelected: (val) => setSheetState(() => _parking = val),
                        ),
                        FilterChip(
                          label: const Text('WiFi'),
                          selected: _wifi,
                          selectedColor: Colors.white,
                          onSelected: (val) => setSheetState(() => _wifi = val),
                        ),
                        FilterChip(
                          label: const Text('Water 24/7'),
                          selected: _water,
                          selectedColor: Colors.white,
                          onSelected: (val) => setSheetState(() => _water = val),
                        ),
                        FilterChip(
                          label: const Text('Security'),
                          selected: _security,
                          selectedColor: Colors.white,
                          onSelected: (val) => setSheetState(() => _security = val),
                        ),
                        FilterChip(
                          label: const Text('Balcony'),
                          selected: _balcony,
                          selectedColor: Colors.white,
                          onSelected: (val) => setSheetState(() => _balcony = val),
                        ),
                        FilterChip(
                          label: const Text('Pet Friendly'),
                          selected: _petFriendly,
                          selectedColor: Colors.white,
                          onSelected: (val) => setSheetState(() => _petFriendly = val),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Verified Only
                    SwitchListTile(
                      title: const Text('Verified Landlords Only', style: TextStyle(color: Colors.white, fontSize: 14)),
                      value: _verifiedOnly,
                      activeThumbColor: Colors.white,
                      onChanged: (val) => setSheetState(() => _verifiedOnly = val),
                      contentPadding: EdgeInsets.zero,
                    ),

                    // Newest first (overrides distance sort while active)
                    SwitchListTile(
                      title: const Text('Newest Listings First', style: TextStyle(color: Colors.white, fontSize: 14)),
                      value: _sortNewestFirst,
                      activeThumbColor: Colors.white,
                      onChanged: (val) => setSheetState(() => _sortNewestFirst = val),
                      contentPadding: EdgeInsets.zero,
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _fetchFiltered();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Apply Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: Colors.white),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) {
                        _debounceTimer?.cancel();
                        _applyClientSideFilters();
                      },
                      decoration: InputDecoration(
                        hintText: CountryService.config.searchHint,
                        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                        prefixIcon: const Icon(Icons.search, color: Colors.white),
                        suffixIcon: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _searchCtrl,
                          builder: (context, value, _) {
                            if (value.text.isEmpty) return const SizedBox.shrink();
                            return IconButton(
                              icon: Icon(Icons.close, color: Colors.grey[500], size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                _debounceTimer?.cancel();
                                _applyClientSideFilters();
                              },
                            );
                          },
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1C1C1E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _showFilterBottomSheet(context),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey[900]!),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.tune, color: Colors.white),
                          if (_activeFilterCount > 0)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                width: 16,
                                height: 16,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                child: Text(
                                  '$_activeFilterCount',
                                  style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      _searchCtrl.clear();
                      _resetFilters();
                    },
                    child: const Text('Reset', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadProperties,
                color: Colors.black,
                backgroundColor: Colors.white,
                child: _loadError
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.6,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.cloud_off, color: Colors.grey[700], size: 64),
                                  const SizedBox(height: 16),
                                  const Text("Couldn't load listings", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Text('Check your connection and try again', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                                  const SizedBox(height: 20),
                                  OutlinedButton(
                                    onPressed: _loadProperties,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(color: Color(0xFF3A3A3C)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : _results.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: MediaQuery.of(context).size.height * 0.6,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.search_off, color: Colors.grey[700], size: 64),
                                      const SizedBox(height: 16),
                                      const Text('No properties found', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Text('Try expanding your price range or clearing filters', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final property = _results[index];
                              final km = _distanceKmTo(property);
                              return PropertyCard(
                                property: property,
                                distanceLabel: km != null ? LocationService.formatDistance(km) : null,
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
