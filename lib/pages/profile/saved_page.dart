import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/favorites_service.dart';
import 'package:roost_app/services/country_service.dart';
import 'package:roost_app/pages/search/property_detail_page.dart';

class SavedPage extends StatefulWidget {
  const SavedPage({super.key});

  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  List<Property> _savedProperties = [];
  bool _loading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final favoriteIds = await FavoritesService.getFavoriteIds();
      if (favoriteIds.isEmpty) {
        if (mounted) {
          setState(() {
            _savedProperties = [];
            _loading = false;
          });
        }
        return;
      }

      final jsonList = await ApiService.get('/api/properties');
      final allProperties = (jsonList as List).map((j) => Property.fromJson(j)).toList();
      if (!mounted) return;

      setState(() {
        _savedProperties = allProperties.where((p) => p.id != null && favoriteIds.contains(p.id)).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _removeFavorite(Property property) async {
    if (property.id == null) return;
    final int propId = property.id!;
    final int index = _savedProperties.indexOf(property);

    await FavoritesService.remove(propId);
    setState(() {
      _savedProperties.removeWhere((p) => p.id == propId);
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${property.title} removed from saved'),
        backgroundColor: const Color(0xFF2C2C2E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.white,
          onPressed: () async {
            await FavoritesService.add(propId);
            setState(() {
              if (index >= 0 && index <= _savedProperties.length) {
                _savedProperties.insert(index, property);
              } else {
                _savedProperties.add(property);
              }
            });
          },
        ),
      ),
    );
  }

  Future<void> _clearAllSaved() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear All Saved Properties?', style: TextStyle(color: Colors.white, fontSize: 18)),
        content: const Text(
          'Are you sure you want to remove all properties from your saved list?',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FavoritesService.clearAll();
      _loadSaved();
    }
  }

  List<Property> get _filteredProperties {
    if (_searchQuery.trim().isEmpty) return _savedProperties;
    final query = _searchQuery.toLowerCase().trim();
    return _savedProperties.where((p) {
      final titleMatch = p.title.toLowerCase().contains(query);
      final locationMatch = p.location.toLowerCase().contains(query);
      final houseTypeMatch = p.houseType.toLowerCase().contains(query);
      return titleMatch || locationMatch || houseTypeMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Saved Properties',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (!_loading && _savedProperties.isNotEmpty)
              Text(
                '${_savedProperties.length} ${_savedProperties.length == 1 ? 'item' : 'items'} saved',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
          ],
        ),
        actions: [
          if (!_loading && _savedProperties.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              color: const Color(0xFF1C1C1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                if (value == 'clear_all') {
                  _clearAllSaved();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 20),
                      SizedBox(width: 10),
                      Text('Clear all saved', style: TextStyle(color: Colors.redAccent, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return _buildSkeletonLoader();
    }

    if (_savedProperties.isEmpty) {
      return _buildEmptyState();
    }

    final displayList = _filteredProperties;

    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: const Color(0xFF1C1C1E),
      onRefresh: _loadSaved,
      child: Column(
        children: [
          // Filter Search Bar if more than 2 saved properties
          if (_savedProperties.length >= 2)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search saved listings...',
                  hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[500], size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, color: Colors.grey[500], size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF1C1C1E),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

          Expanded(
            child: displayList.isEmpty
                ? Center(
                    child: Text(
                      'No saved properties matching "$_searchQuery"',
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 40),
                    itemCount: displayList.length,
                    itemBuilder: (context, index) {
                      final property = displayList[index];
                      return Dismissible(
                        key: Key('saved-${property.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.delete_outline_rounded, color: Colors.white, size: 26),
                              SizedBox(height: 2),
                              Text('Remove', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        onDismissed: (_) => _removeFavorite(property),
                        child: _buildPropertyCard(property),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyCard(Property property) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PropertyDetailPage(property: property)),
          );
          _loadSaved();
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Thumbnail Image with Badges
            Stack(
              children: [
                SizedBox(
                  width: 115,
                  height: 115,
                  child: property.imageUrl != null && property.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: property.imageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(
                            color: const Color(0xFF2C2C2E),
                            child: Icon(Icons.home_outlined, color: Colors.grey[600], size: 36),
                          ),
                        )
                      : Container(
                          color: const Color(0xFF2C2C2E),
                          child: Icon(Icons.home_outlined, color: Colors.grey[600], size: 36),
                        ),
                ),
                if (property.verified)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.verified, color: Colors.greenAccent, size: 10),
                          SizedBox(width: 3),
                          Text('VERIFIED', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            // Main Info Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Title and Heart button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            property.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          onTap: () => _removeFavorite(property),
                          borderRadius: BorderRadius.circular(20),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Location
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, color: Colors.grey[500], size: 13),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            property.location,
                            style: TextStyle(color: Colors.grey[400], fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Property Badges (Bed, Bath, Furnished)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildChip(property.bedroomDisplay, Icons.king_bed_outlined),
                        _buildChip('${property.bathrooms} Bath', Icons.bathtub_outlined),
                        if (property.wifi) _buildChip('WiFi', Icons.wifi_rounded),
                        if (property.furnished) _buildChip('Furnished', Icons.weekend_outlined),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Price
                    Text(
                      CountryService.pricePerMonth(property.price),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.grey[400], size: 10),
          const SizedBox(width: 3),
          Text(text, style: TextStyle(color: Colors.grey[300], fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Icon(Icons.favorite_border_rounded, color: Colors.grey[600], size: 44),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Saved Properties',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Tap the heart icon on any rental listing to bookmark it and quickly access it here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Explore Properties', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 12),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          height: 115,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 115,
                height: 115,
                decoration: const BoxDecoration(
                  color: Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 140, height: 14, color: const Color(0xFF2C2C2E)),
                      const SizedBox(height: 8),
                      Container(width: 100, height: 12, color: const Color(0xFF2C2C2E)),
                      const Spacer(),
                      Container(width: 80, height: 16, color: const Color(0xFF2C2C2E)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
