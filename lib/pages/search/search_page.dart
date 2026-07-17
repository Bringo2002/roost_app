import 'package:flutter/material.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/pages/search/property_detail_page.dart';
import 'package:intl/intl.dart';

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
  String _type = 'all';
  int _minBedrooms = 0;
  RangeValues _priceRange = const RangeValues(0, 500000);
  double _maxPriceLimit = 500000;

  @override
  void initState() {
    super.initState();
    _loadProperties();
    _searchCtrl.addListener(_filterResults);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_filterResults);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProperties() async {
    try {
      final jsonList = await ApiService.get('/api/properties');
      final props = (jsonList as List).map((j) => Property.fromJson(j)).toList();

      double maxPrice = 500000;
      for (var p in props) {
        if (p.price > maxPrice) maxPrice = p.price;
      }
      maxPrice = ((maxPrice / 10000).ceil() * 10000).toDouble();

      setState(() {
        _allProperties = props;
        _results = props; // Show all properties by default
        _maxPriceLimit = maxPrice;
        _priceRange = RangeValues(0, maxPrice);
        _loading = false;
      });
      _filterResults();
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _filterResults() {
    final query = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _results = _allProperties.where((p) {
        final matchesQuery = query.isEmpty ||
            p.title.toLowerCase().contains(query) ||
            p.location.toLowerCase().contains(query);
        final matchesType = _type == 'all' || p.type.toLowerCase() == _type;
        final matchesBedrooms = p.bedrooms >= _minBedrooms;
        final matchesPrice = p.price >= _priceRange.start && p.price <= _priceRange.end;
        return matchesQuery && matchesType && matchesBedrooms && matchesPrice;
      }).toList();

      _results.sort((a, b) => a.price.compareTo(b.price));
    });
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[950],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filters',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            _type = 'all';
                            _minBedrooms = 0;
                            _priceRange = RangeValues(0, _maxPriceLimit);
                          });
                        },
                        child: const Text('Reset All', style: TextStyle(color: Colors.white70)),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 16),

                  // Property type
                  Text('Property Type', style: TextStyle(color: Colors.grey[400], fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['all', 'rental', 'sale', 'airbnb'].map((type) {
                        final isSelected = _type == type;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              type.toUpperCase(),
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: Colors.white,
                            backgroundColor: Colors.grey[900],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: isSelected ? Colors.white : Colors.grey[800]!),
                            ),
                            onSelected: (_) {
                              setSheetState(() => _type = type);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Bedrooms
                  Text('Minimum Bedrooms', style: TextStyle(color: Colors.grey[400], fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  Row(
                    children: List.generate(5, (i) {
                      final isSelected = _minBedrooms == i;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            setSheetState(() => _minBedrooms = i);
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : Colors.grey[900],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSelected ? Colors.white : Colors.grey[800]!),
                            ),
                            child: Center(
                              child: Text(
                                i == 0 ? 'Any' : '$i+',
                                style: TextStyle(
                                  color: isSelected ? Colors.black : Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),

                  // Price range
                  Text('Price Range (KES)', style: TextStyle(color: Colors.grey[400], fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        NumberFormat('#,##0').format(_priceRange.start),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        NumberFormat('#,##0').format(_priceRange.end),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.grey[800],
                      thumbColor: Colors.white,
                      overlayColor: Colors.white.withOpacity(0.1),
                      rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 8),
                      trackHeight: 3,
                    ),
                    child: RangeSlider(
                      values: _priceRange,
                      min: 0,
                      max: _maxPriceLimit,
                      divisions: 50,
                      onChanged: (values) {
                        setSheetState(() => _priceRange = values);
                      },
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Apply button
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
                      child: const Text('Apply Filters', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
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

    final hasActiveFilters = _type != 'all' || _minBedrooms > 0 || _priceRange.start > 0 || _priceRange.end < _maxPriceLimit;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Find your\nperfect home',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 24),

          // Search + Filter Bar Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by location or title...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    prefixIcon: const Icon(Icons.search, color: Colors.white, size: 20),
                    filled: true,
                    fillColor: Colors.grey[900],
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Filter Action Button
              GestureDetector(
                onTap: () => _showFilterBottomSheet(context),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: hasActiveFilters ? Colors.white : Colors.grey[900],
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.tune,
                    color: hasActiveFilters ? Colors.black : Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Results header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_results.length} ${_results.length == 1 ? 'listing' : 'listings'} found',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
              if (hasActiveFilters)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _type = 'all';
                      _minBedrooms = 0;
                      _priceRange = RangeValues(0, _maxPriceLimit);
                    });
                    _filterResults();
                  },
                  child: const Text(
                    'Clear Filters',
                    style: TextStyle(color: Colors.white70, fontSize: 12, decoration: TextDecoration.underline),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Results List
          if (_results.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.search_off, color: Colors.grey[700], size: 48),
                    const SizedBox(height: 12),
                    Text('No properties match your search', style: TextStyle(color: Colors.grey[600], fontSize: 15)),
                  ],
                ),
              ),
            )
          else
            ...List.generate(_results.length, (i) {
              final p = _results[i];
              return InkWell(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => PropertyDetailPage(property: p)));
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      // Mini Thumbnail
                      if (p.imageUrl != null && p.imageUrl!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            p.imageUrl!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[800],
                              child: const Icon(Icons.broken_image, color: Colors.grey, size: 20),
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.home_outlined, color: Colors.white30, size: 24),
                        ),
                      const SizedBox(width: 14),
                      // Text info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 3),
                            Text(p.location, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                            const SizedBox(height: 6),
                            Text('KES ${NumberFormat('#,##0').format(p.price)}', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[700]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(p.type.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, letterSpacing: 0.5)),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bed_outlined, color: Colors.grey[600], size: 14),
                              const SizedBox(width: 3),
                              Text('${p.bedrooms}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
