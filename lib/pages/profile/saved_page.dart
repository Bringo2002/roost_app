import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/favorites_service.dart';
import 'package:roost_app/services/country_service.dart';
import 'package:roost_app/pages/search/property_detail_page.dart';
import 'package:roost_app/main.dart';

enum SavedSortOption {
  recent('All Saved', Icons.auto_awesome_rounded),
  priceLow('Price: Low to High', Icons.arrow_upward_rounded),
  priceHigh('Price: High to Low', Icons.arrow_downward_rounded);

  final String label;
  final IconData icon;
  const SavedSortOption(this.label, this.icon);
}

class SavedPage extends StatefulWidget {
  const SavedPage({super.key});

  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  List<Property> _savedProperties = [];
  bool _loading = true;
  String _searchQuery = '';
  SavedSortOption _selectedSort = SavedSortOption.recent;
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
      final saved = await FavoritesService.getSavedProperties();
      if (!mounted) return;
      setState(() {
        _savedProperties = saved;
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
    if (!mounted) return;
    setState(() {
      _savedProperties.removeWhere((p) => p.id == propId);
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${property.title} removed from saved'),
        backgroundColor: const Color(0xFF2C2C2E),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.greenAccent,
          onPressed: () async {
            await FavoritesService.add(propId);
            if (!mounted) return;
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 10),
            Text('Clear All Saved?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to remove all properties from your saved list? This action cannot be undone.',
          style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FavoritesService.clearAll();
      _loadSaved();
    }
  }

  List<Property> get _processedProperties {
    List<Property> list = List.from(_savedProperties);

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      list = list.where((p) {
        final titleMatch = p.title.toLowerCase().contains(query);
        final locationMatch = p.location.toLowerCase().contains(query);
        final houseTypeMatch = p.houseType.toLowerCase().contains(query);
        return titleMatch || locationMatch || houseTypeMatch;
      }).toList();
    }

    switch (_selectedSort) {
      case SavedSortOption.priceLow:
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case SavedSortOption.priceHigh:
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      case SavedSortOption.recent:
        break;
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101012),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101012),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Text(
              'Saved Properties',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3),
            ),
            if (!_loading && _savedProperties.isNotEmpty) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${_savedProperties.length}',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!_loading && _savedProperties.isNotEmpty)
            PopupMenuButton<String>(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 18),
              ),
              color: const Color(0xFF1C1C1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 20),
                      SizedBox(width: 10),
                      Text('Clear All Saved', style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return _buildFAANGSkeletonLoader();
    }

    if (_savedProperties.isEmpty) {
      return _buildEmptyState();
    }

    final displayList = _processedProperties;

    return RefreshIndicator(
      color: Colors.greenAccent,
      backgroundColor: const Color(0xFF1C1C1E),
      onRefresh: _loadSaved,
      child: Column(
        children: [
          // Search & Sort Bar Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                // Search Input
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search saved by title, area or type...',
                    hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[500], size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.cancel_rounded, color: Colors.grey[500], size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF1C1C1E),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Sort Filter Chips Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: SavedSortOption.values.map((option) {
                      final isSelected = _selectedSort == option;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          showCheckmark: false,
                          avatar: Icon(
                            option.icon,
                            size: 14,
                            color: isSelected ? Colors.black : Colors.grey[400],
                          ),
                          label: Text(
                            option.label,
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.grey[300],
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: Colors.white,
                          backgroundColor: const Color(0xFF1C1C1E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedSort = option);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Property List
          Expanded(
            child: displayList.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded, color: Colors.grey[600], size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'No matches for "$_searchQuery"',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Try adjusting your search terms or filter selection.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[500], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 40),
                    itemCount: displayList.length,
                    itemBuilder: (context, index) {
                      final property = displayList[index];
                      return Dismissible(
                        key: Key('saved-faang-${property.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.delete_forever_rounded, color: Colors.white, size: 28),
                              SizedBox(height: 4),
                              Text('Remove', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        onDismissed: (_) => _removeFavorite(property),
                        child: _buildFAANGPropertyCard(property),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAANGPropertyCard(Property property) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
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
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Thumbnail with Overlay Badges
              Stack(
                children: [
                  SizedBox(
                    width: 130,
                    height: double.infinity,
                    child: property.imageUrl != null && property.imageUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: property.imageUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Container(
                              color: const Color(0xFF2C2C2E),
                              child: Icon(Icons.home_work_outlined, color: Colors.grey[600], size: 36),
                            ),
                          )
                        : Container(
                            color: const Color(0xFF2C2C2E),
                            child: Icon(Icons.home_work_outlined, color: Colors.grey[600], size: 36),
                          ),
                  ),

                  // Dark gradient overlay for bottom badge legibility
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.6),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),

                  // Verified Landlord Pill Badge
                  if (property.verified)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xCC000000),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.verified_rounded, color: Colors.greenAccent, size: 11),
                            SizedBox(width: 3),
                            Text('VERIFIED', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),

                  // House Type Tag Pill
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        property.houseType.toUpperCase(),
                        style: TextStyle(color: Colors.grey[300], fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),

              // Property Info Details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Title & Favorite Toggle Button
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
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _removeFavorite(property),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Location Pin
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded, color: Colors.grey[500], size: 13),
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

                      // Amenity Chips
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildFAANGChip(property.bedroomDisplay, Icons.bed_rounded),
                          _buildFAANGChip('${property.bathrooms} Bath', Icons.shower_rounded),
                          if (property.wifi) _buildFAANGChip('WiFi', Icons.wifi_rounded),
                          if (property.furnished) _buildFAANGChip('Furnished', Icons.chair_rounded),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Price Tag
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            CountryService.pricePerMonth(property.price),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: Colors.grey[600], size: 18),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAANGChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.grey[400], size: 11),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: Colors.grey[300], fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ambient Glowing Heart Badge Icon
            Stack(
              alignment: Alignment.center,
              children: [
                // Outer subtle glow halo
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent.withValues(alpha: 0.06),
                  ),
                ),
                // Inner glow halo
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25), width: 1.5),
                  ),
                ),
                // Center Icon Container
                Container(
                  width: 74,
                  height: 74,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF1C1C1E),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.favorite_border_rounded, color: Colors.redAccent, size: 36),
                ),
              ],
            ),
            const SizedBox(height: 28),

            const Text(
              'No Saved Properties',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3),
            ),
            const SizedBox(height: 10),

            Text(
              'Save your favorite rentals by tapping the heart icon on any listing to compare and access them here anytime.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 14, height: 1.45),
            ),
            const SizedBox(height: 32),

            // High-Contrast Glass CTA Button
            ElevatedButton(
              onPressed: () {
                Navigator.popUntil(context, (route) => route.isFirst);
                mainTabNotifier.value = 0;
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 4,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.explore_rounded, color: Colors.black, size: 18),
                  SizedBox(width: 8),
                  Text('Explore Properties', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAANGSkeletonLoader() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 16),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: const Color(0xFF1C1C1E),
          highlightColor: const Color(0xFF2C2C2E),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 130,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 130,
                  height: 130,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 150, height: 16, color: const Color(0xFF2C2C2E)),
                        const SizedBox(height: 10),
                        Container(width: 100, height: 12, color: const Color(0xFF2C2C2E)),
                        const Spacer(),
                        Row(
                          children: [
                            Container(width: 40, height: 16, color: const Color(0xFF2C2C2E)),
                            const SizedBox(width: 8),
                            Container(width: 40, height: 16, color: const Color(0xFF2C2C2E)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(width: 90, height: 18, color: const Color(0xFF2C2C2E)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
