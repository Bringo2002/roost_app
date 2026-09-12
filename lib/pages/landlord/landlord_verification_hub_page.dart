import 'package:flutter/material.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/location_service.dart';
import 'package:roost_app/pages/landlord/add_property_page.dart';

class LandlordVerificationHubPage extends StatefulWidget {
  const LandlordVerificationHubPage({super.key});

  @override
  State<LandlordVerificationHubPage> createState() => _LandlordVerificationHubPageState();
}

class _LandlordVerificationHubPageState extends State<LandlordVerificationHubPage> {
  List<Property> _properties = [];
  bool _loading = true;
  String? _error;
  final Set<int> _busyPropertyIds = {};

  @override
  void initState() {
    super.initState();
    _fetchVerificationData();
  }

  Future<void> _fetchVerificationData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ApiService.get('/api/properties/my-listings');
      if (!mounted) return;
      final list = (res as List).map((e) => Property.fromJson(e)).toList();
      setState(() {
        _properties = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _verifyGpsForProperty(Property property) async {
    if (property.id == null || _busyPropertyIds.contains(property.id)) return;

    final messenger = ScaffoldMessenger.of(context);
    final pos = await LocationService.getCurrentPosition();
    if (pos == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not obtain current GPS position. Check location permissions.')),
      );
      return;
    }

    setState(() => _busyPropertyIds.add(property.id!));

    try {
      await ApiService.post('/api/properties/${property.id}/verify-gps', {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
      });
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('📍 On-Site GPS position verified successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      await _fetchVerificationData();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('GPS Verification failed: $e')));
    } finally {
      if (mounted) setState(() => _busyPropertyIds.remove(property.id));
    }
  }

  int get _verifiedCount => _properties.where((p) => p.verified).length;
  int get _gpsVerifiedCount => _properties.where((p) => p.gpsVerified).length;
  int get _docVerifiedCount => _properties.where((p) => p.documentVerified).length;

  int _calculateOverallTier() {
    if (_properties.isEmpty) return 1;
    if (_verifiedCount == _properties.length && _properties.isNotEmpty) return 3;
    if (_gpsVerifiedCount > 0 || _docVerifiedCount > 0) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final overallTier = _calculateOverallTier();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F11),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Landlord Verification Center',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _fetchVerificationData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error loading verification status: $_error',
                          style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchVerificationData,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // FAANG Hero Tier Header Banner
                      _buildHeroTierCard(overallTier),

                      const SizedBox(height: 24),

                      // Verification Tiers Breakdown Checklist
                      const Text(
                        'VERIFICATION CHECKPOINTS',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildCheckpointsList(),

                      const SizedBox(height: 28),

                      // Property Verification Status Matrix
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'PROPERTY VERIFICATION MATRIX',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C1C1E),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Text(
                              '$_verifiedCount/${_properties.length} Verified',
                              style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_properties.isEmpty)
                        _buildEmptyListingsCard()
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _properties.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (ctx, idx) => _buildPropertyVerificationRow(_properties[idx]),
                        ),

                      const SizedBox(height: 28),

                      // FAANG Trust Boost Card
                      _buildTrustBoostBanner(),

                      const SizedBox(height: 36),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeroTierCard(int tier) {
    final String tierTitle = tier == 3
        ? 'Tier 3: Platinum Verified Landlord'
        : tier == 2
            ? 'Tier 2: Gold Verified Landlord'
            : 'Tier 1: Basic Verified Landlord';

    final String tierSubtitle = tier == 3
        ? 'All listing ownership proofs & physical GPS checks completed. Maximum tenant trust active.'
        : tier == 2
            ? 'Phone & GPS verified. Upload document proofs to unlock Tier 3 Platinum status.'
            : 'Phone SMS verified. Verify physical GPS and upload ownership proof to reach Tier 3.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: tier == 3
              ? [const Color(0xFF064E3B), const Color(0xFF022C22), const Color(0xFF18181B)]
              : [const Color(0xFF1E293B), const Color(0xFF0F172A), const Color(0xFF18181B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: tier == 3 ? const Color(0xFF10B981).withAlpha(100) : Colors.white12,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (tier == 3 ? const Color(0xFF10B981) : const Color(0xFF3B82F6)).withAlpha(30),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (tier == 3 ? const Color(0xFF10B981) : const Color(0xFF3B82F6)).withAlpha(40),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  tier == 3 ? Icons.verified : Icons.security,
                  color: tier == 3 ? const Color(0xFF10B981) : const Color(0xFF60A5FA),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tierTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Roost Trust Score: ${tier == 3 ? '100%' : tier == 2 ? '66%' : '33%'}',
                      style: TextStyle(
                        color: tier == 3 ? const Color(0xFF34D399) : Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            tierSubtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: tier / 3.0,
              minHeight: 7,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(
                tier == 3 ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckpointsList() {
    return Column(
      children: [
        _buildCheckpointCard(
          title: '📱 Phone & SMS Identity',
          subtitle: 'Cryptographically verified via SMS OTP',
          statusText: 'Verified',
          isDone: true,
          icon: Icons.phone_android,
        ),
        const SizedBox(height: 10),
        _buildCheckpointCard(
          title: '📍 Physical On-Site GPS',
          subtitle: 'Matches physical device coordinates at property',
          statusText: '$_gpsVerifiedCount/${_properties.length} Listings',
          isDone: _gpsVerifiedCount > 0 && _gpsVerifiedCount == _properties.length,
          icon: Icons.location_on,
        ),
        const SizedBox(height: 10),
        _buildCheckpointCard(
          title: '📄 Ownership & Title Deed Proofs',
          subtitle: 'Title deeds, land rate slips, or utility bill attachments',
          statusText: '$_docVerifiedCount/${_properties.length} Uploaded',
          isDone: _docVerifiedCount > 0 && _docVerifiedCount == _properties.length,
          icon: Icons.description,
        ),
      ],
    );
  }

  Widget _buildCheckpointCard({
    required String title,
    required String subtitle,
    required String statusText,
    required bool isDone,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDone ? const Color(0xFF10B981).withAlpha(30) : Colors.white10,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isDone ? const Color(0xFF10B981) : Colors.white54,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDone ? const Color(0xFF10B981).withAlpha(30) : Colors.amber.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: isDone ? const Color(0xFF34D399) : Colors.amber,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyListingsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: const Column(
        children: [
          Icon(Icons.home_work_outlined, color: Colors.white38, size: 40),
          SizedBox(height: 12),
          Text(
            'No Properties Listed Yet',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            'Create your first listing to begin the landlord verification pipeline.',
            style: TextStyle(color: Colors.white54, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyVerificationRow(Property property) {
    final isBusy = property.id != null && _busyPropertyIds.contains(property.id);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: property.verified ? const Color(0xFF10B981).withAlpha(80) : Colors.white.withAlpha(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: property.imageUrls.isNotEmpty
                    ? Image.network(
                        property.imageUrls.first,
                        width: 58,
                        height: 58,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 58,
                          height: 58,
                          color: Colors.grey[800],
                          child: const Icon(Icons.home, color: Colors.white54),
                        ),
                      )
                    : Container(
                        width: 58,
                        height: 58,
                        color: Colors.grey[800],
                        child: const Icon(Icons.home, color: Colors.white54),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            property.title,
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (property.verified)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withAlpha(40),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified, color: Color(0xFF10B981), size: 12),
                                SizedBox(width: 4),
                                Text(
                                  'VERIFIED',
                                  style: TextStyle(color: Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      property.location,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Mini Proof Status Pills
                    Row(
                      children: [
                        _buildProofTag('Phone', true),
                        const SizedBox(width: 6),
                        _buildProofTag('GPS', property.gpsVerified),
                        const SizedBox(width: 6),
                        _buildProofTag('Doc Proof', property.documentVerified),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),

          // Action buttons for missing proofs
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!property.gpsVerified)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : () => _verifyGpsForProperty(property),
                    icon: isBusy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                          )
                        : const Icon(Icons.my_location, size: 14),
                    label: const Text('Verify GPS On-Site', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF38BDF8),
                      side: const BorderSide(color: Color(0xFF0284C7)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddPropertyPage(editingProperty: property),
                    ),
                  );
                  if (result == true) {
                    _fetchVerificationData();
                  }
                },
                icon: Icon(property.verified ? Icons.edit : Icons.upload_file, size: 14),
                label: Text(
                  property.verified ? 'Manage Proofs' : 'Upload Ownership Doc',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: property.verified ? Colors.white12 : const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProofTag(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF10B981).withAlpha(25) : Colors.white10,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.check_circle : Icons.circle_outlined,
            size: 10,
            color: active ? const Color(0xFF34D399) : Colors.white38,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: active ? const Color(0xFF34D399) : Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustBoostBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF38BDF8).withAlpha(60)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0x2038BDF8),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.trending_up, color: Color(0xFF38BDF8), size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '3.5x Tenant Inquiry Multiplier',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Properties with complete Tier 3 proofs earn top placement in search and receive 70% faster booking inquiries.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
