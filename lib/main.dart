import 'dart:async';
import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/pages/auth/welcome_page.dart';
import 'package:roost_app/pages/chat/active_chats_page.dart';
import 'package:roost_app/pages/landlord/listing_intro_page.dart';
import 'package:roost_app/pages/profile/profile_page.dart';
import 'package:roost_app/pages/search/property_detail_page.dart';
import 'package:roost_app/pages/search/search_page.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/auth_service.dart';
import 'package:roost_app/services/favorites_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:roost_app/services/location_service.dart';
import 'package:roost_app/services/country_service.dart';
import 'package:roost_app/utils/property_sorter.dart';
import 'package:roost_app/theme/app_theme.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/theme/app_map_style.dart';
import 'package:roost_app/widgets/property/property_card.dart';

import 'package:roost_app/pages/profile/notifications_page.dart';
import 'package:roost_app/pages/splash/splash_page.dart';
import 'package:roost_app/services/push_notification_service.dart';
import 'package:roost_app/services/navigator_key.dart';
import 'package:roost_app/widgets/common/property_card_skeleton.dart';
import 'package:roost_app/widgets/common/roost_logo_icon.dart';
import 'package:roost_app/widgets/common/roost_search_bar.dart';
import 'firebase_options.dart';

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Keep the native launch screen (android/app/src/main/res/drawable*/
  // splash.png, android12splash.png) on screen past Flutter's first
  // frame, instead of Android dismissing it the instant Flutter is
  // ready to paint. SplashPage calls FlutterNativeSplash.remove() once
  // routing is actually resolved -- this is what gives us real,
  // controlled timing over the ONE native splash view the user sees,
  // without a second Flutter-rendered "splash" screen underneath it.
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Must be registered before runApp so background/terminated messages
  // are never dropped between app launches.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
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

final ValueNotifier<int> mainTabNotifier = ValueNotifier<int>(0);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _currentIndex = 0;
  String _userRole = 'TENANT';
  int _unreadCount = 0;
  Timer? _unreadTimer;
  Key _feedKey = UniqueKey();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _PropertyFeedPage(key: _feedKey),
      const SearchPage(),
      const ActiveChatsPage(),
      const ProfilePage(),
    ];
    mainTabNotifier.addListener(_onMainTabChanged);
    WidgetsBinding.instance.addObserver(this);
    _loadUserRole();
    _startUnreadPolling();
    PushNotificationService.initialize();
  }

  @override
  void dispose() {
    mainTabNotifier.removeListener(_onMainTabChanged);
    WidgetsBinding.instance.removeObserver(this);
    _unreadTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Polling every 60s is wasted battery/network while the app is
    // backgrounded -- nobody sees the badge update until they reopen it
    // anyway, at which point resuming fetches immediately.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _unreadTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _startUnreadPolling();
    }
  }

  void _onMainTabChanged() {
    if (mounted) {
      setState(() {
        _currentIndex = mainTabNotifier.value;
      });
    }
  }

  void _startUnreadPolling() {
    _unreadTimer?.cancel();
    _fetchUnreadCount();
    _unreadTimer = Timer.periodic(const Duration(seconds: 60), (_) {
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
      backgroundColor: AppColors.background,
      appBar: _currentIndex == 2
          ? AppBar(
              title: const Text('Messages'),
              backgroundColor: AppColors.background,
              elevation: 0,
            )
          : null,
      body: SafeArea(
        top: _currentIndex == 0 || _currentIndex == 2,
        bottom: false,
        child: IndexedStack(index: _currentIndex, children: _pages),
      ),
      bottomNavigationBar: _buildPlainBar(),
    );
  }

  Widget _buildPlainBar() {
    return Container(
      color: AppColors.background,
      child: SafeArea(
        top: false,
        bottom: true,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
          ),
          height: 60,
          child: Row(
            children: [
              _navBarItem(
                  index: 0,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Home'),
              _navBarItem(
                  index: 1,
                  icon: Icons.search,
                  activeIcon: Icons.search,
                  label: 'Search'),
              if (_userRole == 'LANDLORD') _centerCreateNavItem(),
              _navBarItem(
                index: 2,
                icon: Icons.message_outlined,
                activeIcon: Icons.message,
                label: 'Messages',
                badgeCount: _unreadCount,
              ),
              _navBarItem(
                  index: 3,
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _centerCreateNavItem() {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          HapticFeedback.mediumImpact();
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ListingIntroPage()),
          );
          if (!mounted) return;
          if (result == true) {
            setState(() {
              _feedKey = UniqueKey();
              _pages[0] = _PropertyFeedPage(key: _feedKey);
            });
          }
        },
        child: Center(
          child: Container(
            width: 44,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppColors.white.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.add_rounded,
              color: AppColors.black,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _navBarItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    int badgeCount = 0,
  }) {
    final selected = _currentIndex == index;
    final color = selected ? AppColors.white : AppColors.grey700;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (_currentIndex != index) HapticFeedback.selectionClick();
          mainTabNotifier.value = index;
          setState(() => _currentIndex = index);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: selected ? 1.08 : 1.0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                    child: Icon(
                      selected ? activeIcon : icon,
                      key: ValueKey(selected),
                      color: color,
                      size: 24,
                    ),
                  ),
                ),
                if (badgeCount > 0) _buildUnreadBadge(badgeCount),
              ],
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                letterSpacing: selected ? 0.5 : 0,
              ),
              child: Text(label),
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
          color: AppColors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
            color: AppColors.black,
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
  bool _isSearchFocused = false;
  bool _isHeaderVisible = true;
  double _lastScrollOffset = 0;
  Timer? _debounceTimer;

  // Pagination -- this feed used to fetch every property in the catalog
  // in one unbounded call. That's fine at a few hundred listings and a
  // real scalability problem beyond that: payload size and load time
  // grow forever as the catalog grows. This now windows through
  // /api/properties (page/size params, opt-in on the backend) the same
  // way the dedicated Search page's /api/properties/filter does --
  // deliberately NOT /filter itself, since that endpoint hardcodes
  // "available = true" and, once lat/lng are sent, "coordinates not
  // null" -- both of which would silently drop listings this feed is
  // supposed to still show (a "Taken" listing displays its own badge
  // rather than disappearing; a listing without pinned coordinates yet
  // still needs to appear, just without a distance label).
  static const int _pageSize = 20;
  int _nextPage = 0;
  bool _hasMore = true;
  bool _loadingMore = false;

  String? _prefHouseType;
  String? _prefBudget;
  String? _prefTimeframe;

  Position? _userPosition;
  String? _userNeighborhood;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadUserPosition();
    searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _searchFocus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    _searchFocus.removeListener(_onFocusChanged);
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

    if (_scrollController.hasClients) {
      final currentOffset = _scrollController.offset;
      if (_isSearchFocused || currentOffset <= 0) {
        if (!_isHeaderVisible) {
          setState(() => _isHeaderVisible = true);
        }
      } else {
        final delta = currentOffset - _lastScrollOffset;
        if (delta > 10 && _isHeaderVisible) {
          setState(() => _isHeaderVisible = false);
        } else if (delta < -10 && !_isHeaderVisible) {
          setState(() => _isHeaderVisible = true);
        }
      }
      _lastScrollOffset = currentOffset;

      if (!_hasMore || _loadingMore || loading) return;
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
        _fetchProperties(loadMore: true);
      }
    }
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer =
        Timer(const Duration(milliseconds: 300), _filterProperties);
  }

  void _onFocusChanged() {
    setState(() => _isSearchFocused = _searchFocus.hasFocus);
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
      if (!mounted) return;
      setState(() {
        _prefHouseType = prefs.getString('pref_house_type');
        _prefBudget = prefs.getString('pref_budget');
        _prefTimeframe = prefs.getString('pref_timeframe');
      });
      _filterProperties();
    } catch (_) {}
  }

  /// Fetches the device location in the background and re-ranks the feed
  /// once it resolves. Runs independently of _loadData so the feed never
  /// waits on location permission before showing properties.
  ///
  /// Re-fetches from page 0 (not just a client re-sort) once location
  /// resolves, since the server now orders by distance once lat/lng is
  /// present -- re-sorting only the already-loaded pages client-side
  /// would leave page boundaries inconsistent with the new server order,
  /// the same page-boundary issue SearchPage's own fetch avoids.
  Future<void> _loadUserPosition() async {
    final position = await LocationService.getCurrentPosition();
    if (!mounted || position == null) return;
    final neighborhood = await LocationService.getNeighborhoodName(position);
    if (!mounted) return;
    setState(() {
      _userPosition = position;
      _userNeighborhood = neighborhood;
      _nextPage = 0;
      _hasMore = true;
    });
    await _fetchProperties();
  }

  /// Distance from the user to [p] in km, or null if either the user's
  /// location or the property's coordinates are unknown. Never falls back
  /// to a default coordinate -- an unknown distance stays unknown.
  double? _distanceKmTo(Property p) {
    final pos = _userPosition;
    final lat = p.latitude;
    final lng = p.longitude;
    if (pos == null || lat == null || lng == null) return null;
    return LocationService.distanceKm(pos.latitude, pos.longitude, lat, lng);
  }

  /// Query string for GET /api/properties (paginated form) -- same
  /// page/size/lat/lng params SearchPage sends to /api/properties/filter,
  /// but against the plain feed endpoint so availability/coordinate
  /// requirements from /filter don't apply here. See the field comment
  /// above for why that distinction matters for this feed specifically.
  String _buildQuery(int page) {
    final params = <String, String>{'page': '$page', 'size': '$_pageSize'};
    final pos = _userPosition;
    if (pos != null) {
      params['lat'] = '${pos.latitude}';
      params['lng'] = '${pos.longitude}';
    }
    return params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
  }

  Future<void> _fetchProperties({bool loadMore = false}) async {
    if (loadMore) {
      if (!_hasMore || _loadingMore) return;
      setState(() => _loadingMore = true);
    }

    final pageToFetch = loadMore ? _nextPage : 0;

    try {
      final query = _buildQuery(pageToFetch);
      final jsonList = await ApiService.get('/api/properties?$query');
      if (!mounted) return;
      final props = (jsonList as List).map((json) => Property.fromJson(json)).toList();
      setState(() {
        properties = loadMore ? [...properties, ...props] : props;
        _hasMore = props.length == _pageSize;
        _nextPage = pageToFetch + 1;
        _error = null;
        loading = false;
        _loadingMore = false;
      });
      _filterProperties();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        _loadingMore = false;
        // A failed "load more" leaves existing results on screen; only
        // a failed initial load shows the full-page error state.
        if (!loadMore) {
          _error = e.toUserMessage('Failed to load properties. Please try again.');
        }
      });
      if (!loadMore) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(
            content: Text(e
                .toUserMessage('Failed to load properties. Please try again.'))));
      }
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


  void _filterProperties() {
    final query = searchController.text.toLowerCase();

    setState(() {
      final matching = properties.where((p) {
        final matchesQuery = p.location.toLowerCase().contains(query) ||
            p.title.toLowerCase().contains(query);
        final matchesType = selectedType == 'all' ||
            p.type.toLowerCase() == selectedType.toLowerCase();
        return matchesQuery && matchesType;
      }).toList();

      filtered = PropertySorter.sort(
        matching,
        userLat: _userPosition?.latitude,
        userLng: _userPosition?.longitude,
        prefHouseType: _prefHouseType,
        prefBudget: _prefBudget,
        prefTimeframe: _prefTimeframe,
      );
    });

    // A text search or type filter can leave too little on screen to
    // fill the viewport even though more pages exist server-side --
    // keep pulling pages until either the filtered set is big enough or
    // the server runs out, the same sparse-results handling
    // SearchPage's own client-side filtering pass already does.
    if (filtered.length < _pageSize && _hasMore && !_loadingMore && !loading) {
      _fetchProperties(loadMore: true);
    }
  }

  // ── Premium loading state — shimmer skeleton + header ──────────────────

  Widget _buildBrandedHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const RoostLogoIcon(size: 26),
          const SizedBox(width: 10),
          const Text(
            'ROOST',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
          const Spacer(),
          ValueListenableBuilder<int>(
            valueListenable: PushNotificationService.unreadCountNotifier,
            builder: (context, unreadCount, child) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsPage(),
                        ),
                      );
                    },
                    tooltip: 'Notifications',
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: const TextStyle(
                            color: AppColors.black,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonFeed() {
    return ListView.builder(
      itemCount: 5,
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemBuilder: (context, index) => const PropertyCardSkeleton(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Column(
        children: [
          _buildBrandedHeader(),
          Expanded(child: _buildSkeletonFeed()),
        ],
      );
    }

    return Column(
      children: [
        // ── Scroll-to-Hide Header (Branded Header + Search Bar) ──
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _isHeaderVisible ? 1.0 : 0.0,
            child: _isHeaderVisible
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildBrandedHeader(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                        child: RoostSearchBar(
                          controller: searchController,
                          focusNode: _searchFocus,
                          hintText: CountryService.config.getDynamicSearchHint(_userNeighborhood),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
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
                        itemCount: filtered.length + (_hasMore ? 1 : 0),
                        padding: const EdgeInsets.only(bottom: 80),
                        itemBuilder: (context, index) {
                          if (index >= filtered.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: _loadingMore
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            );
                          }
                          final property = filtered[index];
                          final km = _distanceKmTo(property);
                          return _StaggeredListItem(
                            index: index,
                            child: PropertyCard(
                              property: property,
                              heroTag: 'property-image-${property.id}',
                              distanceLabel: km != null
                                  ? LocationService.formatDistance(km)
                                  : null,
                              isFavorite: property.id != null &&
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
                            ),
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

/// Animates each feed card in with a staggered fade + upward slide.
/// Only the first 6 items animate — cards below the fold load instantly
/// since the user would never see them animating anyway.
class _StaggeredListItem extends StatefulWidget {
  const _StaggeredListItem({
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  State<_StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<_StaggeredListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    // Stagger: 70ms per card, capped at the 6th card so offscreen
    // items don't delay their load unnecessarily.
    Future.delayed(
      Duration(milliseconds: min(widget.index, 5) * 70),
      () {
        if (mounted) _ctrl.forward();
      },
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ─── Map View Page ────────────────────────────────────────────────────────────────────────────────

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
      CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude), 13),
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
                target: LatLng(geoProperties.first.latitude!,
                    geoProperties.first.longitude!),
                zoom: 12,
              ),
              style: AppMapStyle.darkMapStyle,
              buildingsEnabled: true,
              mapToolbarEnabled: false,
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
