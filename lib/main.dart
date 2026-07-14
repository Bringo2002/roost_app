import 'dart:convert';
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:roost_app/add_property_page.dart';
import 'package:roost_app/property_detail_page.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/auth_service.dart';
import 'package:roost_app/services/favorites_service.dart';
import 'package:roost_app/pages/welcome_page.dart';
import 'package:roost_app/pages/search_page.dart';
import 'package:roost_app/pages/saved_page.dart';
import 'package:roost_app/pages/active_chats_page.dart';
import 'package:roost_app/pages/profile_page.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'config.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Roost',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          onPrimary: Colors.black,
          surface: Colors.black,
        ),
        useMaterial3: true,
      ),
      home: const AuthCheck(),
    );
  }
}

// ─── Auth Check ──────────────────────────────────────────────────────────────

class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    bool loggedIn = await AuthService.isLoggedIn();
    setState(() {
      _isLoggedIn = loggedIn;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    return _isLoggedIn ? const HomePage() : const WelcomePage();
  }
}

// ─── Home Page (Bottom Nav Shell) ────────────────────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  String _userRole = 'TENANT';
  bool _loadingRole = true;
  int _unreadCount = 0;
  Timer? _unreadTimer;
  Key _feedKey = UniqueKey();

  late final List<Widget> _pages;

  final List<String> _titles = const ['ROOST', 'Search', 'Messages', 'Profile'];

  @override
  void initState() {
    super.initState();
    _pages = [
      _PropertyFeedPage(key: _feedKey),
      const SearchPage(),
      const ActiveChatsPage(),
      const ProfilePage(),
    ];
    _loadUserRole();
    _startUnreadPolling();
  }

  @override
  void dispose() {
    _unreadTimer?.cancel();
    super.dispose();
  }

  void _startUnreadPolling() {
    _fetchUnreadCount();
    _unreadTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchUnreadCount();
    });
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final res = await ApiService.get('/api/chat/unread-count');
      if (mounted) {
        setState(() {
          _unreadCount = res['count'] ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadUserRole() async {
    try {
      final user = await ApiService.get('/api/users/me');
      if (mounted) {
        setState(() {
          _userRole = user['role'] ?? 'TENANT';
          _loadingRole = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingRole = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      floatingActionButton: (_currentIndex == 0 && _userRole == 'LANDLORD')
          ? FloatingActionButton(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddPropertyPage()),
                );
                if (result == true) {
                  setState(() {
                    _feedKey = UniqueKey();
                    _pages[0] = _PropertyFeedPage(key: _feedKey);
                  });
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey[900]!, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.black,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.grey[700],
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
            const BottomNavigationBarItem(icon: Icon(Icons.search), activeIcon: Icon(Icons.search), label: 'Search'),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.message_outlined),
                  if (_unreadCount > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$_unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              activeIcon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.message),
                  if (_unreadCount > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$_unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              label: 'Messages',
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

// ─── Property Feed Page (Tab 0) ──────────────────────────────────────────────

class _PropertyFeedPage extends StatefulWidget {
  const _PropertyFeedPage({super.key});

  @override
  State<_PropertyFeedPage> createState() => _PropertyFeedPageState();
}

class _PropertyFeedPageState extends State<_PropertyFeedPage> with SingleTickerProviderStateMixin {
  List<Property> properties = [];
  List<Property> filtered = [];
  Set<int> favoriteIds = {};
  bool loading = true;
  final TextEditingController searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String selectedType = 'all';
  bool sortAscending = true;
  String? _error;
  bool _showSearchBar = false;
  late AnimationController _searchAnimCtrl;
  late Animation<double> _searchAnimation;

  @override
  void initState() {
    super.initState();
    _loadData();
    searchController.addListener(_filterProperties);
    _searchAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _searchAnimation = CurvedAnimation(
      parent: _searchAnimCtrl,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    searchController.removeListener(_filterProperties);
    searchController.dispose();
    _searchFocus.dispose();
    _searchAnimCtrl.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (_showSearchBar) {
        _searchAnimCtrl.forward();
        Future.delayed(const Duration(milliseconds: 200), () {
          _searchFocus.requestFocus();
        });
      } else {
        _searchAnimCtrl.reverse();
        searchController.clear();
        _searchFocus.unfocus();
      }
    });
  }

  Future<void> _loadData() async {
    await Future.wait([_fetchProperties(), _loadFavorites()]);
  }

  Future<void> _fetchProperties() async {
    try {
      final jsonList = await ApiService.get('/api/properties');
      if (!mounted) return;
      setState(() {
        properties = (jsonList as List).map((json) => Property.fromJson(json)).toList();
        filtered = properties;
        _error = null;
        loading = false;
      });
      _filterProperties();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        _error = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading properties: $e')),
      );
    }
  }

  Future<void> _loadFavorites() async {
    final ids = await FavoritesService.getFavoriteIds();
    setState(() => favoriteIds = ids.toSet());
  }

  Future<void> _toggleFavorite(int id) async {
    await FavoritesService.toggle(id);
    await _loadFavorites();
  }

  void _filterProperties() {
    final query = searchController.text.toLowerCase();
    setState(() {
      filtered = properties.where((p) {
        final matchesQuery = p.location.toLowerCase().contains(query) ||
            p.title.toLowerCase().contains(query);
        final matchesType = selectedType == 'all' ||
            p.type.toLowerCase() == selectedType.toLowerCase();
        return matchesQuery && matchesType;
      }).toList();

      filtered.sort((a, b) {
        return sortAscending
            ? a.price.compareTo(b.price)
            : b.price.compareTo(a.price);
      });
    });
  }

  Widget _buildCardImage(Property property) {
    final imageUrl = property.imageUrl;

    Widget imageWidget;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      imageWidget = CachedNetworkImage(
        imageUrl: imageUrl,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          height: 180,
          color: Colors.grey[900],
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white24, strokeWidth: 2),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          height: 180,
          color: Colors.grey[900],
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
          ),
        ),
      );
    } else {
      imageWidget = Container(
        height: 180,
        width: double.infinity,
        color: Colors.grey[900],
        child: Center(
          child: Icon(Icons.home_outlined, color: Colors.grey[700], size: 56),
        ),
      );
    }

    return Stack(
      children: [
        Hero(
          tag: 'property-image-${property.id}',
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: imageWidget,
          ),
        ),
        // Favorite button overlay
        if (property.id != null)
          Positioned(
            top: 10,
            right: 10,
            child: GestureDetector(
              onTap: () => _toggleFavorite(property.id!),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0x99000000),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  favoriteIds.contains(property.id) ? Icons.favorite : Icons.favorite_border,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return Column(
      children: [
        // ── Search bar (animated slide-down) ──
        SizeTransition(
          sizeFactor: _searchAnimation,
          axisAlignment: -1.0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey[800]!, width: 0.5),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Icon(Icons.search, color: Colors.grey[500], size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      focusNode: _searchFocus,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Search location or title...',
                        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 15),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        searchController.clear();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.close, color: Colors.grey[500], size: 18),
                      ),
                    )
                  else
                    const SizedBox(width: 16),
                ],
              ),
            ),
          ),
        ),

        // ── Filter row: chips + search toggle + sort ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['all', 'rental', 'sale', 'airbnb'].map((type) {
                      final isSelected = selectedType == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: GestureDetector(
                          onTap: () {
                            setState(() => selectedType = type);
                            _filterProperties();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.grey[800]!,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              type.toUpperCase(),
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.grey[400],
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Search toggle
              GestureDetector(
                onTap: _toggleSearch,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _showSearchBar ? Colors.white : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _showSearchBar ? Colors.white : Colors.grey[800]!,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.search,
                    color: _showSearchBar ? Colors.black : Colors.grey[500],
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Sort toggle
              GestureDetector(
                onTap: () {
                  setState(() => sortAscending = !sortAscending);
                  _filterProperties();
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[800]!, width: 1),
                  ),
                  child: Icon(
                    sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    color: Colors.grey[500],
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Results count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${filtered.length} ${filtered.length == 1 ? 'property' : 'properties'} found',
              style: TextStyle(color: Colors.grey[600], fontSize: 12, letterSpacing: 0.3),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Property list with pull-to-refresh
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_error != null ? Icons.error_outline : Icons.search_off, color: Colors.grey[700], size: 64),
                      const SizedBox(height: 16),
                      Text(
                        _error ?? 'No properties found',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: Colors.white,
                  backgroundColor: Colors.grey[900],
                  onRefresh: _loadData,
                  child: ListView.builder(
                    itemCount: filtered.length,
                    padding: const EdgeInsets.only(bottom: 80),
                    itemBuilder: (context, index) {
                      final property = filtered[index];
                      return InkWell(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PropertyDetailPage(property: property),
                            ),
                          );
                          _loadFavorites(); // Refresh favorites on return
                        },
                        child: Card(
                          color: Colors.grey[900],
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildCardImage(property),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  property.title,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (property.verified) ...[
                                                const SizedBox(width: 4),
                                                const Icon(Icons.verified, color: Colors.white, size: 18),
                                              ],
                                              if (property.holdingFeePaid) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0x1AFFFFFF),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: Colors.white54),
                                                  ),
                                                  child: const Text(
                                                    'UNDER OFFER',
                                                    style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: property.available ? Colors.white : Colors.grey[700],
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(Icons.location_on, color: Colors.grey[500], size: 14),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            property.location,
                                            style: TextStyle(color: Colors.grey[400]),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'KES ${NumberFormat('#,##0').format(property.price)}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.grey[700]!),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            property.type.toUpperCase(),
                                            style: const TextStyle(color: Colors.white, fontSize: 11, letterSpacing: 0.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.bed_outlined, color: Colors.grey[600], size: 16),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${property.bedrooms} bedroom',
                                              style: TextStyle(color: Colors.grey[500], fontSize: 13),
                                            ),
                                          ],
                                        ),
                                        if (property.reviewCount > 0)
                                          Row(
                                            children: [
                                              const Icon(Icons.star, color: Colors.amber, size: 16),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${property.averageRating.toStringAsFixed(1)} (${property.reviewCount})',
                                                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── Map View Page ───────────────────────────────────────────────────────────

class MapViewPage extends StatelessWidget {
  final List<Property> properties;

  const MapViewPage({super.key, required this.properties});

  @override
  Widget build(BuildContext context) {
    final geoProperties = properties.where((p) => p.latitude != null && p.longitude != null).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${geoProperties.length} on map',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: geoProperties.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined, color: Colors.grey[700], size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'No properties have\nlocation coordinates yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                ],
              ),
            )
          : FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(
                  geoProperties.first.latitude!,
                  geoProperties.first.longitude!,
                ),
                initialZoom: 12.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.roost.app',
                ),
                MarkerLayer(
                  markers: geoProperties.map((p) {
                    return Marker(
                      point: LatLng(p.latitude!, p.longitude!),
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PropertyDetailPage(property: p),
                            ),
                          );
                        },
                        child: const Icon(
                          Icons.location_pin,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
    );
  }
}
