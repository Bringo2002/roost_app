import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:roost_app/models/country_config.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/auth_service.dart';
import 'package:roost_app/services/country_service.dart';
import 'package:roost_app/services/location_service.dart';
import 'package:roost_app/services/onboarding_service.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/widgets/auth/apple_sign_in_button.dart';
import 'package:roost_app/widgets/auth/google_sign_in_button.dart';
import 'package:roost_app/widgets/common/roost_logo_icon.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

class OnboardingPage extends StatefulWidget {
  final int initialStep;

  const OnboardingPage({super.key, this.initialStep = 0});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {
  int _step = 0;
  CountryConfig _selectedCountry = CountryService.config;
  String _houseType = 'ANY';
  int _previousStep = 0;
  int _selectedBudgetIndex = 0;
  String _moveInTimeframe = 'This Month';

  bool _requestingLocation = false;
  bool _showCountryList = false;

  bool _isLoginMode = false;
  bool _isAuthLoading = false;
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  // Preview step state
  List<Property> _previewProperties = [];
  int _previewTotalCount = 0;
  bool _previewLoading = false;
  bool _previewFetched = false;
  String? _previewError;

  // Welcome entrance animation
  late final AnimationController _welcomeAnimCtrl;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoGlow;
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _subtitleOpacity;
  late final List<Animation<double>> _featureOpacities;
  late final List<Animation<Offset>> _featureSlides;

  // Progress bar celebration glow
  late final AnimationController _progressGlowCtrl;
  int _lastGlowStep = -1;

  @override
  void initState() {
    super.initState();
    _step = widget.initialStep;
    _selectedCountry = CountryService.config;
    _selectedBudgetIndex = 0;

    // Welcome entrance: 1200ms staggered animation
    _welcomeAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _welcomeAnimCtrl,
        curve: const Interval(0.0, 0.35, curve: Curves.elasticOut),
      ),
    );

    _logoGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _welcomeAnimCtrl,
        curve: const Interval(0.15, 0.55, curve: Curves.easeOut),
      ),
    );

    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _welcomeAnimCtrl,
        curve: const Interval(0.25, 0.50, curve: Curves.easeOut),
      ),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _welcomeAnimCtrl,
        curve: const Interval(0.25, 0.50, curve: Curves.easeOut),
      ),
    );

    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _welcomeAnimCtrl,
        curve: const Interval(0.35, 0.60, curve: Curves.easeOut),
      ),
    );

    // Staggered feature items (3 items, each 120ms apart)
    _featureOpacities = List.generate(3, (i) {
      final start = 0.45 + i * 0.12;
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _welcomeAnimCtrl,
          curve: Interval(start, (start + 0.20).clamp(0, 1), curve: Curves.easeOut),
        ),
      );
    });

    _featureSlides = List.generate(3, (i) {
      final start = 0.45 + i * 0.12;
      return Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _welcomeAnimCtrl,
          curve: Interval(start, (start + 0.20).clamp(0, 1), curve: Curves.easeOut),
        ),
      );
    });

    // Progress glow: quick 500ms pulse
    _progressGlowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Start welcome animation if on step 0
    if (_step == 0) {
      _welcomeAnimCtrl.forward();
    } else {
      _welcomeAnimCtrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _welcomeAnimCtrl.dispose();
    _progressGlowCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  final List<Map<String, dynamic>> _houseTypes = [
    {'title': 'Bedsitter', 'value': 'BEDSITTER', 'icon': Icons.bed_outlined, 'desc': 'Compact & affordable'},
    {'title': 'Studio', 'value': 'STUDIO', 'icon': Icons.single_bed_outlined, 'desc': 'Open plan layout'},
    {'title': '1 Bedroom', 'value': '1BR', 'icon': Icons.apartment, 'desc': 'Separate living area'},
    {'title': '2 Bedroom', 'value': '2BR', 'icon': Icons.home_outlined, 'desc': 'Ideal for sharing/couples'},
    {'title': '3 Bedroom+', 'value': '3BR+', 'icon': Icons.domain, 'desc': 'Spacious family homes'},
    {'title': 'Any', 'value': 'ANY', 'icon': Icons.grid_view_rounded, 'desc': 'Show all property types'},
  ];

  List<BudgetOption> get _budgets => _selectedCountry.budgets;

  List<Map<String, dynamic>> get _timeframes {
    return [
      {'title': 'Immediately', 'icon': Icons.flash_on_outlined, 'desc': 'Ready to view and sign today'},
      {'title': 'Within 2 Weeks', 'icon': Icons.calendar_today_outlined, 'desc': 'Planning ahead for next move'},
      {'title': 'This Month', 'icon': Icons.date_range_outlined, 'desc': 'Exploring current month availability'},
      {'title': 'Just Browsing', 'icon': Icons.search_outlined, 'desc': _selectedCountry.browsingDesc},
    ];
  }

  Future<void> _nextStep() async {
    switch (_step) {
      case 2:
        await OnboardingService.markStepComplete(_step, data: {
          OnboardingService.houseTypeKey: _houseType,
        });
      case 3:
        final budget = _selectedCountry.budgets[_selectedBudgetIndex];
        await OnboardingService.markStepComplete(_step, data: {
          OnboardingService.budgetKey: budget.title,
          OnboardingService.budgetMinKey: budget.minPrice,
          OnboardingService.budgetMaxKey: budget.maxPrice,
        });
      case 4:
        await OnboardingService.markStepComplete(_step, data: {
          OnboardingService.timeframeKey: _moveInTimeframe,
        });
      default:
        await OnboardingService.markStepComplete(_step);
    }
    if (_step < 6) {
      final nextStep = _step + 1;
      setState(() {
        _previousStep = _step;
        _step = nextStep;
      });
      // Trigger progress bar celebration glow
      if (nextStep >= 1 && nextStep <= 5) {
        _triggerProgressGlow(nextStep);
      }
      if (nextStep == 5 && !_previewFetched) {
        _fetchPreviewProperties();
      }
    }
  }

  /// Fires a quick shimmer pulse on the progress bar segment that just filled.
  void _triggerProgressGlow(int step) {
    _lastGlowStep = step;
    _progressGlowCtrl.forward(from: 0.0);
  }

  Future<void> _handleLocationStep() async {
    setState(() => _requestingLocation = true);
    try {
      final position = await LocationService.getCurrentPosition();
      if (position != null) {
        await OnboardingService.markStepComplete(1, data: {
          OnboardingService.locationLatKey: position.latitude,
          OnboardingService.locationLngKey: position.longitude,
        });
        final detected = await CountryService.instance.autoDetectCountry();
        if (detected != null && mounted) {
          _selectedCountry = detected;
          _selectedBudgetIndex = 0;
          await CountryService.instance.setCountry(detected);
        }
      } else {
        await OnboardingService.markStepComplete(1);
      }
    } catch (_) {
      await OnboardingService.markStepComplete(1);
    }
    if (!mounted) return;
    setState(() {
      _requestingLocation = false;
      _previousStep = _step;
      _step = 2;
    });
  }

  Future<void> _skipLocation() async {
    await OnboardingService.markStepComplete(1);
    if (!mounted) return;
    setState(() {
      _previousStep = _step;
      _step = 2;
    });
  }

  /// Fetches a small page of properties matching the user's onboarding
  /// preferences to display as blurred preview cards.
  Future<void> _fetchPreviewProperties() async {
    if (_previewLoading) return;
    setState(() {
      _previewLoading = true;
      _previewError = null;
    });

    try {
      // Build a lightweight query from the user's saved preferences.
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(OnboardingService.locationLatKey)
          ?? _selectedCountry.mapCenter.latitude;
      final lng = prefs.getDouble(OnboardingService.locationLngKey)
          ?? _selectedCountry.mapCenter.longitude;

      final params = <String, String>{
        'page': '0',
        'size': '10', // Fetch a few extra so we can filter client-side
        'lat': '$lat',
        'lng': '$lng',
      };

      final query = params.entries
          .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
          .join('&');

      final jsonList = await ApiService.get('/api/properties?$query');
      if (!mounted) return;

      final allProps = (jsonList as List)
          .map((json) => Property.fromJson(json))
          .toList();

      // Client-side filter by the user's house type and budget preferences.
      final houseType = _houseType;
      final budget = _selectedCountry.budgets[_selectedBudgetIndex];
      final filtered = allProps.where((p) {
        final typeMatch = houseType == 'ANY' || p.houseType == houseType;
        final budgetMatch = p.price >= budget.minPrice
            && (budget.maxPrice == double.infinity || p.price <= budget.maxPrice);
        return typeMatch && budgetMatch;
      }).toList();

      setState(() {
        // Show filtered results if we have any, otherwise show all (still
        // valuable — real photos behind blur are compelling regardless).
        _previewProperties = filtered.isNotEmpty
            ? filtered.take(3).toList()
            : allProps.take(3).toList();
        _previewTotalCount = filtered.isNotEmpty
            ? filtered.length
            : allProps.length;
        _previewLoading = false;
        _previewFetched = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _previewLoading = false;
        _previewFetched = true;
        _previewError = e.toString();
      });
    }
  }

  void _prevStep() {
    if (_step > 0) {
      setState(() {
        _previousStep = _step;
        _step--;
      });
    }
  }

  Future<void> _handleEmailAuth() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }
    setState(() => _isAuthLoading = true);
    final AuthResult result;
    if (_isLoginMode) {
      result = await AuthService.login(email, password);
    } else {
      final name = _nameCtrl.text.trim();
      if (name.isEmpty) {
        setState(() => _isAuthLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your name')),
        );
        return;
      }
      result = await AuthService.signup(name, email, password);
    }
    if (!mounted) return;
    setState(() => _isAuthLoading = false);
    await _handleAuthResult(result);
  }

  Future<void> _handleGoogleAuth() async {
    setState(() => _isAuthLoading = true);
    final result = await AuthService.signInWithGoogle();
    if (!mounted) return;
    setState(() => _isAuthLoading = false);
    await _handleAuthResult(result);
  }

  Future<void> _handleAppleAuth() async {
    setState(() => _isAuthLoading = true);
    final result = await AuthService.signInWithApple();
    if (!mounted) return;
    setState(() => _isAuthLoading = false);
    if (result.success || result.error != null) {
      await _handleAuthResult(result);
    }
  }

  Future<void> _handleAuthResult(AuthResult result) async {
    if (result.success) {
      await CountryService.instance.setCountry(_selectedCountry);
      final dest = await OnboardingService.getPostAuthDestination(
        result,
        isInOnboardingFlow: true,
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => dest.widget),
        (route) => false,
      );
    } else if (result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error!), duration: const Duration(seconds: 4)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const goldAccent = Colors.white;
    final showProgress = _step >= 1 && _step <= 5;
    final showBottomButton = _step <= 5;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: _prevStep,
              )
            : null,
        title: const Text(
          'ROOST',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 4),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress Bar (steps 1-5 only)
              if (showProgress) ...[
                Row(
                  children: List.generate(
                    5,
                    (index) => Expanded(
                      child: AnimatedBuilder(
                        animation: _progressGlowCtrl,
                        builder: (context, child) {
                          final isFilled = index < _step;
                          final isGlowing = isFilled && index == (_lastGlowStep - 1);
                          final glowValue = isGlowing ? _progressGlowCtrl.value : 0.0;
                          // Pulse: 0→1→0 via sin curve
                          final glowIntensity = isGlowing
                              ? (1.0 - (2.0 * glowValue - 1.0).abs())
                              : 0.0;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: isFilled ? goldAccent : AppColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: glowIntensity > 0
                                  ? [
                                      BoxShadow(
                                        color: AppColors.goldMuted
                                            .withValues(alpha: 0.8 * glowIntensity),
                                        blurRadius: 12 * glowIntensity,
                                        spreadRadius: 2 * glowIntensity,
                                      ),
                                    ]
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],

              // Step Content
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    final isForward = _step >= _previousStep;
                    final slideIn = Tween<Offset>(
                      begin: Offset(isForward ? 0.15 : -0.15, 0),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: slideIn, child: child),
                    );
                  },
                  child: _buildCurrentStep(goldAccent),
                ),
              ),

              if (showBottomButton) ...[
                const SizedBox(height: 16),
                // Main action button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _requestingLocation
                        ? null
                        : _step == 1
                            ? _handleLocationStep
                            : _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: goldAccent,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.grey[800],
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      _step == 0
                          ? 'Get Started'
                          : _step == 1
                              ? (_requestingLocation ? 'Requesting Access...' : 'Allow Location Access')
                              : _step == 5
                                  ? 'Show My Homes'
                                  : 'Continue',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ),
                ),
                // Skip button for location step only
                if (_step == 1 && !_requestingLocation) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: _skipLocation,
                      child: Text(
                        'Skip for now',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep(Color goldAccent) {
    switch (_step) {
      case 0:
        return _buildWelcomeStep(goldAccent);
      case 1:
        return _buildLocationStep(goldAccent);
      case 2:
        return _buildHouseTypeStep(goldAccent);
      case 3:
        return _buildBudgetStep(goldAccent);
      case 4:
        return _buildTimelineStep(goldAccent);
      case 5:
        return _buildPreviewStep(goldAccent);
      case 6:
        return _buildAuthStep(goldAccent);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildWelcomeStep(Color goldAccent) {
    final features = [
      (Icons.shield_outlined, 'Verified by Roost', 'No fake listings. Every home is reviewed before it goes live.'),
      (Icons.chat_bubble_outline, 'Chat with Landlords', 'Reach property owners directly and get answers fast.'),
      (Icons.map_outlined, 'See Exactly Where It Is', 'Find the exact spot — not just the area.'),
    ];

    return AnimatedBuilder(
      animation: _welcomeAnimCtrl,
      builder: (context, _) => Column(
        key: const ValueKey(0),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          // Logo: scale-in with elastic bounce + subtle glow
          Transform.scale(
            scale: _logoScale.value,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: _logoGlow.value > 0
                    ? [
                        BoxShadow(
                          color: AppColors.goldMuted
                              .withValues(alpha: 0.4 * _logoGlow.value),
                          blurRadius: 24 * _logoGlow.value,
                          spreadRadius: 4 * _logoGlow.value,
                        ),
                      ]
                    : null,
              ),
              child: const RoostLogoIcon(size: 64),
            ),
          ),
          const SizedBox(height: 20),
          // Title: fade + slide up
          SlideTransition(
            position: _titleSlide,
            child: Opacity(
              opacity: _titleOpacity.value,
              child: const Text(
                'Find a place that\nfeels like yours.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Subtitle: fade in
          Opacity(
            opacity: _subtitleOpacity.value,
            child: Text(
              'Verified rentals near you — browse, chat with landlords, and move in faster.',
              style: TextStyle(color: Colors.grey[400], fontSize: 14, height: 1.5),
            ),
          ),
          const SizedBox(height: 32),
          // Feature items: staggered cascade
          ...List.generate(features.length, (i) {
            final (icon, title, subtitle) = features[i];
            return Padding(
              padding: EdgeInsets.only(bottom: i < features.length - 1 ? 16 : 0),
              child: SlideTransition(
                position: _featureSlides[i],
                child: Opacity(
                  opacity: _featureOpacities[i].value,
                  child: _buildFeatureItem(icon, title, subtitle, goldAccent),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLocationStep(Color goldAccent) {
    if (_showCountryList) {
      return Column(
        key: const ValueKey('country_select'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          const Text(
            'Where are you\nlooking?',
            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, height: 1.2),
          ),
          const SizedBox(height: 8),
          Text(
            'Select your country so we can show the right listings.',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.2,
              children: CountryConfig.all.map((c) {
                final isSelected = _selectedCountry.code == c.code;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedCountry = c;
                      _selectedBudgetIndex = 0;
                      _showCountryList = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(c.flag, style: const TextStyle(fontSize: 26)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                c.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                c.currencyCode,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle, color: Colors.white, size: 18),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      );
    }

    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey[850]!),
          ),
          child: Icon(Icons.my_location_rounded, color: goldAccent, size: 40),
        ),
        const SizedBox(height: 24),
        const Text(
          "See what's\naround you",
          style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, height: 1.2),
        ),
        const SizedBox(height: 12),
        Text(
          'We\'ll sort by what\'s closest, so your next home is never far away.',
          style: TextStyle(color: Colors.grey[400], fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 32),
        _buildFeatureItem(Icons.sort, 'Closest first', 'Homes near you are always at the top.', goldAccent),
        const SizedBox(height: 16),
        _buildFeatureItem(Icons.lock_outline, 'Only used for search', 'Your location is never shared with landlords or other users.', goldAccent),
      ],
    );
  }

  Widget _buildHouseTypeStep(Color goldAccent) {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What type of home\nare you looking for?',
          style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, height: 1.2),
        ),
        const SizedBox(height: 8),
        Text('Pick one — we\'ll show you more of what you want.', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        const SizedBox(height: 24),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
            ),
            itemCount: _houseTypes.length,
            itemBuilder: (context, index) {
              final item = _houseTypes[index];
              final title = item['title'] as String;
              final value = item['value'] as String;
              final icon = item['icon'] as IconData;
              final desc = item['desc'] as String;
              final selected = _houseType == value;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _houseType = value);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected ? goldAccent.withValues(alpha: 0.1) : AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? goldAccent : Colors.grey[900]!,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(icon, color: selected ? goldAccent : Colors.grey[400], size: 24),
                          if (selected)
                            Icon(Icons.check_circle, color: goldAccent, size: 18),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.grey[200],
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            desc,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey[500], fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetStep(Color goldAccent) {
    final budgets = _budgets;
    return Column(
      key: const ValueKey(3),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "What's your\nmonthly budget?",
          style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, height: 1.2),
        ),
        const SizedBox(height: 8),
        Text('We\'ll highlight homes in your range.', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        const SizedBox(height: 24),
        Expanded(
          child: ListView.builder(
            itemCount: budgets.length,
            itemBuilder: (context, index) {
              final item = budgets[index];
              final title = item.title;
              final badge = item.badge;
              final desc = item.desc;
              final selected = _selectedBudgetIndex == index;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedBudgetIndex = index);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selected ? goldAccent.withValues(alpha: 0.1) : AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? goldAccent : Colors.grey[900]!,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    color: selected ? goldAccent : Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[900],
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey[800]!),
                                  ),
                                  child: Text(
                                    badge,
                                    style: TextStyle(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(desc, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          ],
                        ),
                      ),
                      if (selected)
                        Icon(Icons.check_circle, color: goldAccent, size: 22),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineStep(Color goldAccent) {
    return Column(
      key: const ValueKey(4),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'When are you planning\nto move in?',
          style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, height: 1.2),
        ),
        const SizedBox(height: 8),
        Text('This helps us show what\'s available when you need it.', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        const SizedBox(height: 24),
        Expanded(
          child: ListView.builder(
            itemCount: _timeframes.length,
            itemBuilder: (context, index) {
              final item = _timeframes[index];
              final title = item['title'] as String;
              final icon = item['icon'] as IconData;
              final desc = item['desc'] as String;
              final selected = _moveInTimeframe == title;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _moveInTimeframe = title);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selected ? goldAccent.withValues(alpha: 0.1) : AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? goldAccent : Colors.grey[900]!,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: selected ? goldAccent.withValues(alpha: 0.2) : Colors.grey[900],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: selected ? goldAccent : Colors.grey[400], size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.grey[200],
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(desc, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          ],
                        ),
                      ),
                      if (selected)
                        Icon(Icons.check_circle, color: goldAccent, size: 22),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewStep(Color goldAccent) {
    // Dynamic header based on fetched results.
    final hasResults = _previewProperties.isNotEmpty;
    final countText = _previewTotalCount > 0
        ? '$_previewTotalCount verified rental${_previewTotalCount == 1 ? '' : 's'}'
        : 'homes';

    return Column(
      key: const ValueKey(5),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasResults
              ? 'We found $countText\nfor you'
              : 'We found your\nhomes',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          hasResults
              ? 'Matching your budget and style — sign up to explore them all.'
              : 'Homes that fit your budget and style are ready to explore.',
          style: TextStyle(color: Colors.grey[500], fontSize: 13),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _previewLoading
                ? _buildPreviewShimmer()
                : _previewError != null && _previewProperties.isEmpty
                    ? _buildPreviewFallback(goldAccent)
                    : ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: ListView(
                          physics: const NeverScrollableScrollPhysics(),
                          children: _previewProperties.isNotEmpty
                              ? _previewProperties
                                  .map((p) => _buildRealPreviewCard(p))
                                  .toList()
                              : List.generate(
                                  3, (index) => _buildPlaceholderCard()),
                        ),
                      ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, color: Colors.grey[500], size: 16),
            const SizedBox(width: 6),
            Text(
              'Create a free account to see them all',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Shimmer loading state for the preview cards.
  Widget _buildPreviewShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[850]!,
      highlightColor: Colors.grey[700]!,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(3, (_) => _buildPlaceholderCard()),
      ),
    );
  }

  /// Fallback when the API fails or returns 0 results.
  Widget _buildPreviewFallback(Color goldAccent) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey[850]!),
              ),
              child: Icon(
                Icons.home_work_outlined,
                color: goldAccent,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Properties are being added\nin your area',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your account to be the first\nto know when new homes go live.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a preview card with real property data behind the blur.
  Widget _buildRealPreviewCard(Property property) {
    final imageUrl = property.imageUrls.isNotEmpty
        ? property.imageUrls.first
        : property.imageUrl;
    final formattedPrice = CountryService.pricePerMonth(property.price);

    return Container(
      height: 120,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[850]!),
      ),
      child: Row(
        children: [
          // Real property image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 96,
              height: 96,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: Colors.grey[800],
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey[800],
                        child: Icon(
                          Icons.home_outlined,
                          color: Colors.grey[600],
                          size: 32,
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.grey[800],
                      child: Icon(
                        Icons.home_outlined,
                        color: Colors.grey[600],
                        size: 32,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Property title / building name
                Text(
                  property.buildingName ?? property.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                // Location
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        color: Colors.grey[500], size: 12),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        property.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // House type badge
                Text(
                  property.houseType.replaceAll('_', ' '),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                // Price
                Text(
                  formattedPrice,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Skeleton placeholder card (used as fallback when no real data is available).
  Widget _buildPlaceholderCard() {
    return Container(
      height: 120,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[850]!),
      ),
      child: Row(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 14,
                  width: 140,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  width: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  width: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 16,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthStep(Color goldAccent) {
    return SingleChildScrollView(
      key: const ValueKey(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          const RoostLogoIcon(size: 48),
          const SizedBox(height: 20),
          Text(
            _isLoginMode ? 'Welcome\nback' : 'Almost there',
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, height: 1.2),
          ),
          const SizedBox(height: 8),
          Text(
            _isLoginMode
                ? 'Your feed is just as you left it.'
                : 'Create your account to start browsing.',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
          const SizedBox(height: 28),

          GoogleSignInButton(onPressed: _isAuthLoading ? null : _handleGoogleAuth),
          if (AuthService.isAppleSignInAvailable) ...[
            const SizedBox(height: 12),
            AppleSignInButton(onPressed: _isAuthLoading ? null : _handleAppleAuth),
          ],

          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey[900])),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('OR', style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              Expanded(child: Divider(color: Colors.grey[900])),
            ],
          ),
          const SizedBox(height: 20),

          if (!_isLoginMode) ...[
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: _authInputDecoration('Full Name', Icons.person_outline),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _emailCtrl,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.emailAddress,
            decoration: _authInputDecoration('Email Address', Icons.email_outlined),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordCtrl,
            style: const TextStyle(color: Colors.white),
            obscureText: _obscurePassword,
            decoration: _authInputDecoration(
              'Password',
              Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.grey[500],
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isAuthLoading ? null : _handleEmailAuth,
              style: ElevatedButton.styleFrom(
                backgroundColor: goldAccent,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.grey[800],
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isAuthLoading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : Text(
                      _isLoginMode ? 'Log In' : 'Create Account',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isLoginMode ? "Don't have an account? " : 'Already have an account? ',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
              GestureDetector(
                onTap: () => setState(() => _isLoginMode = !_isLoginMode),
                child: Text(
                  _isLoginMode ? 'Sign Up' : 'Log In',
                  style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  InputDecoration _authInputDecoration(String label, IconData icon, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w400),
      prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.surfaceContainer,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white, width: 1.5),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle, Color goldAccent) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[850]!),
          ),
          child: Icon(icon, color: goldAccent, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}
