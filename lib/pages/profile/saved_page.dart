import 'package:flutter/material.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/favorites_service.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/pages/search/property_detail_page.dart';
import 'package:roost_app/main.dart';
import 'package:roost_app/widgets/common/roost_search_bar.dart';
import 'package:roost_app/widgets/common/property_card_skeleton.dart';
import 'package:roost_app/widgets/property/property_card.dart';

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
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadSaved();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
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
        backgroundColor: AppColors.grey800,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: AppColors.white,
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
        backgroundColor: AppColors.surfaceRaised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
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
              backgroundColor: AppColors.error,
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
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
                  color: AppColors.favoriteActive.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.favoriteActive.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${_savedProperties.length}',
                  style: const TextStyle(color: AppColors.favoriteActive, fontSize: 12, fontWeight: FontWeight.w800),
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
              color: AppColors.surfaceRaised,
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
                      Icon(Icons.delete_sweep_rounded, color: AppColors.error, size: 20),
                      SizedBox(width: 10),
                      Text('Clear All Saved', style: TextStyle(color: AppColors.error, fontSize: 14, fontWeight: FontWeight.w600)),
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
      // Reuses the same skeleton PropertyCard itself uses elsewhere in
      // the app, now that this page renders real PropertyCards too --
      // previously this page had its own bespoke skeleton shaped for
      // the old compact row layout, which no longer matches.
      return ListView.builder(
        padding: const EdgeInsets.only(top: 16),
        itemCount: 4,
        itemBuilder: (context, index) => const PropertyCardSkeleton(),
      );
    }

    if (_savedProperties.isEmpty) {
      return _buildEmptyState();
    }

    final displayList = _processedProperties;

    return RefreshIndicator(
      color: AppColors.white,
      backgroundColor: AppColors.surfaceRaised,
      onRefresh: _loadSaved,
      child: Column(
        children: [
          // Search & Sort Bar Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                // Search Input -- was its own hand-rolled TextField with
                // raw hex colors and no focus feedback, unlike every other
                // search box in the app. Now uses the same shared widget
                // as the home feed and Search page.
                RoostSearchBar(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  hintText: 'Search saved by title, area or type...',
                  onClear: () => setState(() => _searchQuery = ''),
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
                          backgroundColor: AppColors.surfaceRaised,
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
                        key: Key('saved-item-${property.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: AppColors.destructiveGradient,
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
                        // Previously a bespoke, un-migrated card copy
                        // (bare Image, no memory-capped decoding, no
                        // shimmer/error placeholder, no stale-gallery
                        // fix) -- now the same PropertyCard used on the
                        // home feed and Search page everywhere else.
                        child: PropertyCard(
                          key: ValueKey(property.id ?? identityHashCode(property)),
                          property: property,
                          compact: true,
                          heroTag: property.id != null ? 'property-image-${property.id}' : null,
                          // Every property on this page is, by definition,
                          // already saved -- tapping the heart here means
                          // "remove", same as swiping the row away.
                          isFavorite: true,
                          onFavoriteTap: () => _removeFavorite(property),
                          // Default PropertyCard onTap is a bare
                          // Navigator.push with no return handling. This
                          // page specifically needs to reload on return,
                          // since unfavoriting from the detail page should
                          // drop the item from this list too.
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => PropertyDetailPage(property: property)),
                            );
                            _loadSaved();
                          },
                        ),
                      );
                    },
                  ),
          ),
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
                    color: AppColors.favoriteActive.withValues(alpha: 0.06),
                  ),
                ),
                // Inner glow halo
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.favoriteActive.withValues(alpha: 0.12),
                    border: Border.all(color: AppColors.favoriteActive.withValues(alpha: 0.25), width: 1.5),
                  ),
                ),
                // Center Icon Container
                Container(
                  width: 74,
                  height: 74,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceRaised,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.favorite_border_rounded, color: AppColors.favoriteActive, size: 36),
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
}
