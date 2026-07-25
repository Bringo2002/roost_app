import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/country_service.dart';
import 'package:roost_app/services/location_service.dart';
import 'package:roost_app/widgets/property/property_card.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  List<Property> _allProperties = [];
  List<Property> _results = [];
  bool _loading = true;

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
    _debounceTimer = Timer(const Duration(milliseconds: 300), _filterResults);
  }

  Future<void> _loadUserLocation() async {
    final position = await LocationService.getCurrentPosition();
    if (!mounted || position == null) return;
    setState(() {
      _userPosition = position;
    });
    _filterResults();
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
    try {
      final jsonList = await ApiService.get('/api/properties');
      final props = (jsonList as List).map((j) => Property.fromJson(j)).toList();

      if (!mounted) return;
      setState(() {
        _allProperties = props;
        _results = props;
        _loading = false;
      });
      _filterResults();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filterResults() {
    final query = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _results = _allProperties.where((p) {
        final matchesQuery = query.isEmpty ||
            p.title.toLowerCase().contains(query) ||
            p.location.toLowerCase().contains(query) ||
            p.houseType.toLowerCase().contains(query);

        final matchesHouseType = _houseType == 'All' ||
            p.houseType.toLowerCase() == _houseType.toLowerCase() ||
            (_houseType == '3BR+' && p.bedrooms >= 3);

        final matchesBedrooms = _bedrooms == 0 || p.bedrooms >= _bedrooms;
        final matchesPrice = p.price >= _priceRange.start && p.price <= _priceRange.end;
        final matchesVerified = !_verifiedOnly || p.verified;

        final matchesFurnished = !_furnished || p.furnished;
        final matchesParking = !_parking || p.parking;
        final matchesWifi = !_wifi || p.wifi;
        final matchesWater = !_water || p.water;
        final matchesSecurity = !_security || p.security;
        final matchesBalcony = !_balcony || p.balcony;
        final matchesPetFriendly = !_petFriendly || p.petFriendly;

        return matchesQuery &&
            matchesHouseType &&
            matchesBedrooms &&
            matchesPrice &&
            matchesVerified &&
            matchesFurnished &&
            matchesParking &&
            matchesWifi &&
            matchesWater &&
            matchesSecurity &&
            matchesBalcony &&
            matchesPetFriendly;
      }).toList();

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
    });
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
    _filterResults();
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
                                type,
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
                          _filterResults();
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
                      decoration: InputDecoration(
                        hintText: CountryService.config.searchHint,
                        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                        prefixIcon: const Icon(Icons.search, color: Colors.white),
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
                      child: const Icon(Icons.tune, color: Colors.white),
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
              child: _results.isEmpty
                  ? Center(
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
                    )
                  : ListView.builder(
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
          ],
        ),
      ),
    );
  }
}
