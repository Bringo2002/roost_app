import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/pages/auth/welcome_page.dart';
import 'package:roost_app/pages/chat/active_chats_page.dart';
import 'package:roost_app/pages/landlord/add_property_page.dart';
import 'package:roost_app/pages/profile/profile_page.dart';
import 'package:roost_app/pages/search/property_detail_page.dart';
import 'package:roost_app/pages/search/search_page.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/auth_service.dart';
import 'package:roost_app/services/favorites_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:roost_app/services/location_service.dart';
import 'package:roost_app/theme/app_theme.dart';
import 'package:roost_app/theme/app_map_style.dart';
import 'package:roost_app/widgets/property/property_card.dart';

import 'package:roost_app/pages/splash/splash_page.dart';
import 'package:roost_app/services/push_notification_service.dart';

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
      theme: AppTheme.darkTheme,
      home: const SplashPage(),
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
    final loggedIn = await AuthService.isLoggedIn();
    if (!mounted) return;
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
    PushNotificationService.initialize();
  }

  @override
  void dispose() {
    _unreadTimer?.cancel();
    super.dispose();
  }

  void _startUnreadPolling() {
    _fetchUnreadCount();
    _unreadTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchUnreadCount();
    });
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final res = await ApiService.get('/api/chat/unread-count');
      if (!mounted) return;
      setState(() {
        _unreadCount = res['count'] ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _loadUserRole() async {
    try {
      final user = await ApiService.get('/api/users/me');
      if (!mounted) return;
      setState(() {
        _userRole = user['role'] ?? 'TENANT';
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _currentIndex == 0
          ? null
          : AppBar(title: Text(_titles[_currentIndex])),
      body: SafeArea(
        top: _currentIndex == 0,
        bottom: false,
        child: IndexedStack(index: _currentIndex, children: _pages),
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
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.search),
              activeIcon: Icon(Icons.search),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.message_outlined),
                  if (_unreadCount > 0) _buildUnreadBadge(_unreadCount),
                ],
              ),
              activeIcon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.message),
                  if (_unreadCount > 0) _buildUnreadBadge(_unreadCount),
                ],
              ),
              label: 'Messages',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnreadBadge(int count) {
    return Positioned(
      right: -6,
      top: -6,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(8),
        ),
        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
        child: Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
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

class _PropertyFeedPageState extends State<_PropertyFeedPage> {
  List<Property> properties = [];
  List<Property> filtered = [];
  Set<int> favoriteIds = {};
  bool loading = true;

  final TextEditingController searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();

  String selectedType = 'all';
  String? _error;
  bool _showScrollToTop = false;
  Timer? _debounceTimer;

  String? _prefHouseType;
  String? _prefBudget;
  String? _prefTimeframe;

  @override
  void initState() {
    super.initState();
    _loadData();
    searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    _searchFocus.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    final show = _scrollController.offset > 600;
    if (show != _showScrollToTop) {
      setState(() => _showScrollToTop = show);
    }
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), _filterProperties);
  }

  Future<void> _loadData() async {
    await Future.wait([
      _fetchProperties(),
      _loadFavorites(),
      _loadOnboardingPrefs(),
    ]);
  }

  Future<void> _loadOnboardingPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _prefHouseType = prefs.getString('pref_house_type');
        _prefBudget = prefs.getString('pref_budget');
        _prefTimeframe = prefs.getString('pref_timeframe');
      });
      _filterProperties();
    } catch (_) {}
  }

  Future<void> _fetchProperties() async {
    try {
      final jsonList = await ApiService.get('/api/properties');
      if (!mounted) return;
      setState(() {
        properties = (jsonList as List)
            .map((json) => Property.fromJson(json))
            .toList();
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading properties: $e')));
    }
  }

  Future<void> _loadFavorites() async {
    final ids = await FavoritesService.getFavoriteIds();
    if (!mounted) return;
    setState(() => favoriteIds = ids.toSet());
  }

  Future<void> _toggleFavorite(int id) async {
    await FavoritesService.toggle(id);
    await _loadFavorites();
  }

  int _calculateRelevance(Property p) {
    int score = 0;

    // 1. House Type match (+10 pts)
    if (_prefHouseType != null && _prefHouseType != 'Any') {
      final prefType = _prefHouseType!.toLowerCase().replaceAll(' ', '');
      final pType = p.houseType.toLowerCase().replaceAll(' ', '');
      if (pType.contains(prefType) || prefType.contains(pType)) {
        score += 10;
      }
    }

    // 2. Budget Range match (+10 pts)
    if (_prefBudget != null) {
      final b = _prefBudget!;
      if (b.contains('Under 15') && p.price < 15000) score += 10;
      if (b.contains('15k – 30k') && p.price >= 15000 && p.price <= 30000) score += 10;
      if (b.contains('30k – 60k') && p.price >= 30000 && p.price <= 60000) score += 10;
      if (b.contains('60,000+') && p.price >= 60000) score += 10;
    }

    // 3. Move-in Immediate (+5 pts)
    if (_prefTimeframe == 'Immediately' && p.available) {
      score += 5;
    }

    // 4. Verified bonus (+2 pts)
    if (p.verified) score += 2;

    return score;
  }

  void _filterProperties() {
    final query = searchController.text.toLowerCase();

    setState(() {
      filtered = properties.where((p) {
        final matchesQuery =
            p.location.toLowerCase().contains(query) ||
            p.title.toLowerCase().contains(query);
        final matchesType =
            selectedType == 'all' ||
            p.type.toLowerCase() == selectedType.toLowerCase();
        return matchesQuery && matchesType;
      }).toList()
        ..sort((a, b) {
          final relA = _calculateRelevance(a);
          final relB = _calculateRelevance(b);
          if (relA != relB) {
            return relB.compareTo(relA); // higher relevance first
          }
          return a.price.compareTo(b.price);
        });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Column(
      children: [
        // ── Search bar (always visible) ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
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
                      hintStyle: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),
                if (searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: searchController.clear,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(
                        Icons.close,
                        color: Colors.grey[500],
                        size: 18,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 16),
              ],
            ),
          ),
        ),

        // Property list with pull-to-refresh
        Expanded(
          child: Stack(
            children: [
              filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _error != null
                                ? Icons.error_outline
                                : Icons.search_off,
                            color: Colors.grey[700],
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _error ?? 'No properties found',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: Colors.white,
                      backgroundColor: Colors.grey[900],
                      onRefresh: _loadData,
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount: filtered.length,
                        padding: const EdgeInsets.only(bottom: 80),
                        itemBuilder: (context, index) {
                          final property = filtered[index];
                          return PropertyCard(
                            property: property,
                            heroTag: 'property-image-${property.id}',
                            isFavorite:
                                property.id != null &&
                                favoriteIds.contains(property.id),
                            onFavoriteTap: property.id == null
                                ? null
                                : () => _toggleFavorite(property.id!),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      PropertyDetailPage(property: property),
                                ),
                              );
                              _loadFavorites();
                            },
                          );
                        },
                      ),
                    ),

              // Scroll-to-top button
              if (_showScrollToTop)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: AnimatedOpacity(
                    opacity: _showScrollToTop ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: GestureDetector(
                      onTap: () {
                        _scrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                        );
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x40000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.black,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Map View Page ───────────────────────────────────────────────────────────

class MapViewPage extends StatefulWidget {
  final List<Property> properties;

  const MapViewPage({super.key, required this.properties});

  @override
  State<MapViewPage> createState() => _MapViewPageState();
}

class _MapViewPageState extends State<MapViewPage> {
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _centerOnUserLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _centerOnUserLocation() async {
    final position = await LocationService.getCurrentPosition();
    if (position == null || !mounted) return;
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(position.latitude, position.longitude), 13),
    );
  }

  @override
  Widget build(BuildContext context) {
    final geoProperties = widget.properties
        .where((p) => p.latitude != null && p.longitude != null)
        .toList();

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
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(geoProperties.first.latitude!, geoProperties.first.longitude!),
                zoom: 12,
              ),
              style: AppMapStyle.darkMapStyle,
              onMapCreated: (controller) {
                _mapController = controller;
                _centerOnUserLocation();
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              markers: geoProperties.map((p) {
                return Marker(
                  markerId: MarkerId('property-${p.id}'),
                  position: LatLng(p.latitude!, p.longitude!),
                  infoWindow: InfoWindow(title: p.title, snippet: p.location),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PropertyDetailPage(property: p),
                      ),
                    );
                  },
                );
              }).toSet(),
            ),
    );
  }
}
