import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:roost_app/main.dart';
import 'package:roost_app/services/location_service.dart';
import 'package:roost_app/widgets/common/roost_logo_icon.dart';
import 'package:roost_app/models/country_config.dart';
import 'package:roost_app/services/country_service.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _step = 0;

  CountryConfig _selectedCountry = CountryService.config;
  String _houseType = 'Any';
  String _budget = '';
  String _moveInTimeframe = 'This Month';

  // Auto-detection state
  bool _isDetecting = true;
  bool _detectionFailed = false;
  bool _showCountryList = false;
  bool _requestingLocation = false;

  @override
  void initState() {
    super.initState();
    _selectedCountry = CountryService.config;
    _budget = _selectedCountry.budgets.isNotEmpty ? _selectedCountry.budgets[0].title : '';
    _autoDetectCountry();
  }

  Future<void> _autoDetectCountry() async {
    setState(() {
      _isDetecting = true;
      _detectionFailed = false;
    });

    final detected = await CountryService.instance.autoDetectCountry();

    if (!mounted) return;

    if (detected != null) {
      setState(() {
        _selectedCountry = detected;
        _budget = detected.budgets.isNotEmpty ? detected.budgets[0].title : '';
        _isDetecting = false;
        _detectionFailed = false;
      });
    } else {
      setState(() {
        _isDetecting = false;
        _detectionFailed = true;
        _showCountryList = true; // Show manual picker on failure
      });
    }
  }

  final List<Map<String, dynamic>> _houseTypes = [
    {'title': 'Bedsitter', 'icon': Icons.bed_outlined, 'desc': 'Compact & affordable'},
    {'title': 'Studio', 'icon': Icons.single_bed_outlined, 'desc': 'Open plan layout'},
    {'title': '1 Bedroom', 'icon': Icons.apartment, 'desc': 'Separate living area'},
    {'title': '2 Bedroom', 'icon': Icons.home_outlined, 'desc': 'Ideal for sharing/couples'},
    {'title': '3 Bedroom+', 'icon': Icons.domain, 'desc': 'Spacious family homes'},
    {'title': 'Any', 'icon': Icons.grid_view_rounded, 'desc': 'Show all property types'},
  ];

  List<Map<String, dynamic>> get _budgets {
    return _selectedCountry.budgets.map((b) => {
      'title': b.title,
      'badge': b.badge,
      'desc': b.desc,
    }).toList();
  }

  List<Map<String, dynamic>> get _timeframes {
    return [
      {'title': 'Immediately', 'icon': Icons.flash_on_outlined, 'desc': 'Ready to view and sign today'},
      {'title': 'Within 2 Weeks', 'icon': Icons.calendar_today_outlined, 'desc': 'Planning ahead for next move'},
      {'title': 'This Month', 'icon': Icons.date_range_outlined, 'desc': 'Exploring current month availability'},
      {'title': 'Just Browsing', 'icon': Icons.search_outlined, 'desc': _selectedCountry.browsingDesc},
    ];
  }

  Future<void> _completeOnboarding() async {
    await CountryService.instance.setCountry(_selectedCountry);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pref_house_type', _houseType);
    await prefs.setString('pref_budget', _budget);
    await prefs.setString('pref_timeframe', _moveInTimeframe);
    await prefs.setBool('onboarding_completed', true);

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  void _nextStep() {
    if (_step < 5) {
      setState(() => _step++);
    } else {
      _completeOnboarding();
    }
  }

  /// Requests device location, then advances -- granted or denied, the
  /// onboarding flow never blocks on this, since location is an
  /// enhancement to the feed, not a requirement to use the app.
  Future<void> _handleLocationStep() async {
    setState(() => _requestingLocation = true);
    await LocationService.getCurrentPosition();
    if (!mounted) return;
    setState(() => _requestingLocation = false);
    _nextStep();
  }

  void _prevStep() {
    if (_step > 0) {
      setState(() => _step--);
    }
  }

  @override
  Widget build(BuildContext context) {
    const goldAccent = Colors.white;

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
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _completeOnboarding,
            child: const Text('Skip', style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress Bar (6 steps total)
              Row(
                children: List.generate(
                  6,
                  (index) => Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: index <= _step ? goldAccent : const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Step Content Switcher
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _buildCurrentStep(goldAccent),
                ),
              ),

              const SizedBox(height: 16),

              // Bottom Action Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_step == 0 && _isDetecting) || _requestingLocation
                      ? null
                      : (_step == 2 ? _handleLocationStep : _nextStep),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: goldAccent,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.grey[800],
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    _step == 0
                        ? (_isDetecting ? 'Detecting Location...' : 'Continue')
                        : _step == 1
                            ? 'Get Started'
                            : _step == 2
                                ? (_requestingLocation ? 'Requesting Access...' : 'Allow Location Access')
                                : _step == 5
                                    ? 'Curate My Feed'
                                    : 'Continue',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep(Color goldAccent) {
    switch (_step) {
      case 0:
        return _buildCountryDetectionStep(goldAccent);
      case 1:
        return _buildWelcomeStep(goldAccent);
      case 2:
        return _buildLocationPermissionStep(goldAccent);
      case 3:
        return _buildHouseTypeStep(goldAccent);
      case 4:
        return _buildBudgetStep(goldAccent);
      case 5:
        return _buildTimelineStep(goldAccent);
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Step 0: Auto-Detect Country ────────────────────────────────────

  Widget _buildCountryDetectionStep(Color goldAccent) {
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        const RoostLogoIcon(size: 72),
        const SizedBox(height: 24),
        const Text(
          'Where are you\nlooking to rent?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We auto-detect your location to personalize pricing, currency, and listings.',
          style: TextStyle(color: Colors.grey[400], fontSize: 14),
        ),
        const SizedBox(height: 28),

        // Detection result / loading
        if (_isDetecting) ...[
          _buildDetectingCard(),
        ] else if (!_showCountryList) ...[
          _buildDetectedCountryCard(goldAccent),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _showCountryList = true),
              icon: const Icon(Icons.edit_location_alt_outlined, color: Colors.grey, size: 18),
              label: Text(
                'Not your location? Change country',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
            ),
          ),
        ],

        // Country list (shown on failure or if user taps "Change")
        if (_showCountryList) ...[
          if (_detectionFailed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orangeAccent, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Could not detect location. Please select manually.',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
            ),
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
                    setState(() {
                      _selectedCountry = c;
                      if (c.budgets.isNotEmpty) {
                        _budget = c.budgets[0].title;
                      }
                      _showCountryList = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
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
      ],
    );
  }

  Widget _buildDetectingCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[850]!),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detecting your location...',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Using GPS to find your country automatically',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectedCountryCard(Color goldAccent) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(_selectedCountry.flag, style: const TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    const Text(
                      'Detected Location',
                      style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _selectedCountry.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_selectedCountry.currencyCode} • ${_selectedCountry.currencySymbol}',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Colors.white, size: 24),
        ],
      ),
    );
  }

  // ── Step 1: Welcome & Value Proposition ─────────────────────────

  Widget _buildWelcomeStep(Color goldAccent) {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        const RoostLogoIcon(size: 72),
        const SizedBox(height: 24),
        const Text(
          'Find Verified Homes.\nZero Brokers.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Roost connects you directly with verified landlords with transparent pricing and real-time availability.',
          style: TextStyle(color: Colors.grey[400], fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 32),

        // Value Cards
        _buildFeatureItem(
          Icons.shield_outlined,
          '100% Verified Listings',
          'Every listing is checked for accuracy and authenticity.',
          goldAccent,
        ),
        const SizedBox(height: 16),
        _buildFeatureItem(
          Icons.chat_bubble_outline,
          'Direct Landlord Chat',
          'Cut out middleman fees and connect directly in seconds.',
          goldAccent,
        ),
        const SizedBox(height: 16),
        _buildFeatureItem(
          Icons.map_outlined,
          'Precise Location Mapping',
          'Navigate to exact property coordinates on the map.',
          goldAccent,
        ),
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle, Color goldAccent) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
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
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 2: Location Permission ──────────────────────────────────

  Widget _buildLocationPermissionStep(Color goldAccent) {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
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
          'Roost shows you verified rentals closest to you first, with real distance to every listing.',
          style: TextStyle(color: Colors.grey[400], fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 32),
        _buildFeatureItem(
          Icons.sort,
          'Sorted by distance',
          'Nearby homes always appear first in your feed.',
          goldAccent,
        ),
        const SizedBox(height: 16),
        _buildFeatureItem(
          Icons.lock_outline,
          'Only used for search',
          'Your location is never shared with landlords or other users.',
          goldAccent,
        ),
      ],
    );
  }

  // ── Step 3: House Type Selection ─────────────────────────────────

  Widget _buildHouseTypeStep(Color goldAccent) {
    return Column(
      key: const ValueKey(3),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What type of home\nare you looking for?',
          style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, height: 1.2),
        ),
        const SizedBox(height: 8),
        Text('We will customize your feed accordingly', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
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
              final icon = item['icon'] as IconData;
              final desc = item['desc'] as String;
              final selected = _houseType == title;

              return GestureDetector(
                onTap: () => setState(() => _houseType = title),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected ? goldAccent.withValues(alpha: 0.1) : const Color(0xFF1C1C1E),
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

  // ── Step 4: Budget Curation ──────────────────────────────────────

  Widget _buildBudgetStep(Color goldAccent) {
    return Column(
      key: const ValueKey(4),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "What is your target\nmonthly budget?",
          style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, height: 1.2),
        ),
        const SizedBox(height: 8),
        Text('We show you verified listings matching your price point', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        const SizedBox(height: 24),
        Expanded(
          child: ListView.builder(
            itemCount: _budgets.length,
            itemBuilder: (context, index) {
              final item = _budgets[index];
              final title = item['title'] as String;
              final badge = item['badge'] as String;
              final desc = item['desc'] as String;
              final selected = _budget == title;

              return GestureDetector(
                onTap: () => setState(() => _budget = title),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selected ? goldAccent.withValues(alpha: 0.1) : const Color(0xFF1C1C1E),
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

  // ── Step 5: Move-in Timeline ────────────────────────────────────

  Widget _buildTimelineStep(Color goldAccent) {
    return Column(
      key: const ValueKey(5),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'When are you planning\nto move in?',
          style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, height: 1.2),
        ),
        const SizedBox(height: 8),
        Text('We will prioritize listings available immediately', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
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
                onTap: () => setState(() => _moveInTimeframe = title),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selected ? goldAccent.withValues(alpha: 0.1) : const Color(0xFF1C1C1E),
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
}
