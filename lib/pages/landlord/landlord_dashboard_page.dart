import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shimmer/shimmer.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/country_service.dart';
import 'package:roost_app/services/location_service.dart';
import 'package:roost_app/pages/landlord/add_property_page.dart';
import 'package:roost_app/pages/landlord/landlord_verification_hub_page.dart';
import 'package:roost_app/pages/landlord/endorsement_page.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/theme/app_text_styles.dart';
import 'package:roost_app/widgets/landlord/landlord_property_card.dart';
import 'package:url_launcher/url_launcher.dart';

class LandlordDashboardPage extends StatefulWidget {
  const LandlordDashboardPage({super.key});

  @override
  State<LandlordDashboardPage> createState() => _LandlordDashboardPageState();
}

class _LandlordDashboardPageState extends State<LandlordDashboardPage> {
  List<Property> _myListings = [];
  bool _loading = true;
  String _selectedFilter = 'ALL';

  /// Ids of listings with an action (publish, verify-gps, delete,
  /// toggle-availability) currently in flight. Guards every per-listing
  /// action below so a slow round trip can't be fired twice from a
  /// double-tap, and lets the UI show a spinner instead of sitting
  /// silently unresponsive while the request is out.
  final Set<int> _busyIds = {};

  bool _isBusy(Property property) => property.id != null && _busyIds.contains(property.id);

  @override
  void initState() {
    super.initState();
    _loadListings();
  }

  Future<void> _loadListings() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final jsonList = await ApiService.get('/api/properties/my-listings');
      if (!mounted) return;
      setState(() {
        _myListings = (jsonList as List).map((j) => Property.fromJson(j)).toList()
          ..sort((a, b) => a.status == b.status ? 0 : (a.status == 'DRAFT' ? -1 : 1));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load listings: $e')),
      );
    }
  }

  List<Property> get _filteredListings {
    switch (_selectedFilter) {
      case 'PUBLISHED':
        return _myListings.where((p) => p.status == 'PUBLISHED' && p.available).toList();
      case 'DRAFT':
        return _myListings.where((p) => p.status == 'DRAFT').toList();
      case 'RENTED':
        return _myListings.where((p) => !p.available).toList();
      case 'ALL':
      default:
        return _myListings;
    }
  }

  Future<void> _toggleAvailability(Property property) async {
    if (property.id == null || _isBusy(property)) return;

    if (property.available) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceRaised,
          title: const Text('Mark as Rented?', style: TextStyle(color: Colors.white)),
          content: const Text(
            'This listing will disappear from discovery. You can mark it available again anytime.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Mark as Rented'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _busyIds.add(property.id!));
    try {
      await ApiService.patch('/api/properties/${property.id}/availability', {
        'available': !property.available,
      });
      await _loadListings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busyIds.remove(property.id));
    }
  }

  Future<void> _deleteListing(Property property) async {
    if (property.id == null || _isBusy(property)) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        title: const Text('Delete Listing', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this listing?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _busyIds.add(property.id!));
    try {
      await ApiService.delete('/api/properties/${property.id}');
      await _loadListings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    } finally {
      if (mounted) setState(() => _busyIds.remove(property.id));
    }
  }

  Future<void> _verifyGps(Property property) async {
    if (property.id == null || _isBusy(property)) return;

    final position = await LocationService.getCurrentPosition();
    if (position == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not get your location. Check that location services are enabled.')),
      );
      return;
    }

    setState(() => _busyIds.add(property.id!));
    try {
      await ApiService.post('/api/properties/${property.id}/verify-gps', {
        'latitude': position.latitude,
        'longitude': position.longitude,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📍 On-Site GPS Location Verified! Your physical presence has been confirmed at this property.'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadListings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(property.id));
    }
  }

  Future<void> _publishDraft(Property property) async {
    if (property.id == null || _isBusy(property)) return;

    setState(() => _busyIds.add(property.id!));
    try {
      await ApiService.patch('/api/properties/${property.id}/publish', {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listing published')),
      );
      await _loadListings();
    } catch (e) {
      if (!mounted) return;
      final proceedToWizard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceRaised,
          title: const Text('Could not publish', style: TextStyle(color: Colors.white)),
          content: Text(
            'This usually means your phone isn\'t verified yet. Open the listing to verify and publish?',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Open Listing')),
          ],
        ),
      );
      if (proceedToWizard == true && mounted) {
        final updated = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => AddPropertyPage(editingProperty: property)),
        );
        if (updated == true) _loadListings();
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(property.id));
    }
  }

  void _shareLandlordEndorsement(Property property) async {
    final token = property.endorsementToken ?? '';
    final ownerPhone = (property.ownerVerifyPhone ?? '').replaceAll(' ', '');
    final ownerName = property.ownerVerifyName ?? 'Landlord';
    final title = property.title;

    final msg = Uri.encodeComponent(
      'Hi $ownerName, I listed $title on Roost. Please open the link below to confirm me as your caretaker & grant the Landlord Endorsement trust badge:\n\nhttps://roost.app/endorse?token=$token',
    );

    final cleanPhone = ownerPhone.replaceAll('+', '');
    final whatsappUri = Uri.parse('https://wa.me/$cleanPhone?text=$msg');

    if (cleanPhone.isNotEmpty && await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        final result = await Navigator.push<Property>(
          context,
          MaterialPageRoute(
            builder: (_) => EndorsementPage(
              initialToken: token,
              property: property,
            ),
          ),
        );
        if (result != null) _loadListings();
      }
    }
  }

  Widget _buildStatsHeader() {
    final totalCount = _myListings.length;
    final draftsCount = _myListings.where((p) => p.status == 'DRAFT').length;
    final availableCount = _myListings.where((p) => p.status == 'PUBLISHED' && p.available).length;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF18181B),
            const Color(0xFF0F172A).withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'Total Listings',
            totalCount,
            Icons.home_work_outlined,
            Colors.white,
            'ALL',
          ),
          Container(width: 1, height: 36, color: AppColors.border),
          _buildStatItem(
            'Drafts',
            draftsCount,
            Icons.edit_note_rounded,
            Colors.amber,
            'DRAFT',
          ),
          Container(width: 1, height: 36, color: AppColors.border),
          _buildStatItem(
            'Available',
            availableCount,
            Icons.check_circle_outline_rounded,
            AppColors.accent,
            'PUBLISHED',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value, IconData icon, Color color, String filterKey) {
    final isSelected = _selectedFilter == filterKey;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilter = filterKey);
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: value),
                  duration: AppColors.durationMedium,
                  builder: (context, val, _) {
                    return Text(
                      '$val',
                      style: AppTextStyles.sectionHeader.copyWith(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textTertiary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChipsRow() {
    final publishedCount = _myListings.where((p) => p.status == 'PUBLISHED' && p.available).length;
    final draftsCount = _myListings.where((p) => p.status == 'DRAFT').length;
    final rentedCount = _myListings.where((p) => !p.available).length;
    final totalCount = _myListings.length;

    final filterOptions = [
      {'key': 'ALL', 'label': 'All ($totalCount)'},
      {'key': 'PUBLISHED', 'label': 'Available ($publishedCount)'},
      {'key': 'DRAFT', 'label': 'Drafts ($draftsCount)'},
      {'key': 'RENTED', 'label': 'Rented ($rentedCount)'},
    ];

    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filterOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = filterOptions[index];
          final key = option['key'] as String;
          final label = option['label'] as String;
          final isSelected = _selectedFilter == key;

          return ChoiceChip(
            selected: isSelected,
            label: Text(label),
            labelStyle: TextStyle(
              color: isSelected ? Colors.black : Colors.white70,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
            selectedColor: Colors.white,
            backgroundColor: AppColors.surface,
            side: BorderSide(
              color: isSelected ? Colors.white : AppColors.border,
              width: 1,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            onSelected: (selected) {
              if (selected) {
                HapticFeedback.selectionClick();
                setState(() => _selectedFilter = key);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildVerificationCenterBanner() {
    final verifiedCount = _myListings.where((p) => p.verified).length;
    final totalCount = _myListings.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0x3010B981),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Landlord Verification Center',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  totalCount == 0
                      ? 'Complete account & listing proof checks'
                      : '$verifiedCount/$totalCount Listings Fully Verified',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LandlordVerificationHubPage()),
              ).then((_) => _loadListings());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Manage', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
      itemCount: 4,
      itemBuilder: (_, __) => const _LandlordCardSkeleton(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayedListings = _filteredListings;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('My Listings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? _buildSkeletonLoading()
          : RefreshIndicator(
              color: Colors.white,
              backgroundColor: AppColors.surfaceRaised,
              onRefresh: _loadListings,
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
                children: [
                  _buildVerificationCenterBanner(),
                  _buildStatsHeader(),
                  _buildFilterChipsRow(),
                  if (displayedListings.isEmpty)
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.4,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.business_center_outlined, color: AppColors.textTertiary, size: 56),
                            const SizedBox(height: 14),
                            Text(
                              _selectedFilter == 'ALL'
                                  ? 'No properties listed yet'
                                  : 'No $_selectedFilter listings',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap the "+" button on Home feed to add a new listing',
                              style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayedListings.length,
                      itemBuilder: (context, index) {
                        final property = displayedListings[index];
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: Duration(milliseconds: 400 + (index * 50)),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 20 * (1 - value)),
                                child: child,
                              ),
                            );
                          },
                          child: LandlordPropertyCard(
                            key: ValueKey(property.id),
                            property: property,
                            isBusy: _isBusy(property),
                            onEdit: () async {
                              final updated = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(builder: (_) => AddPropertyPage(editingProperty: property)),
                              );
                              if (updated == true) _loadListings();
                            },
                            onDelete: () => _deleteListing(property),
                            onToggleAvailability: (_) => _toggleAvailability(property),
                            onPublish: () => _publishDraft(property),
                            onViewApplications: () => _viewApplications(property),
                            onVerifyGps: () => _verifyGps(property),
                            onShareEndorsement: () => _shareLandlordEndorsement(property),
                            onViewEndorsementBadge: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EndorsementPage(
                                    initialToken: property.endorsementToken,
                                    property: property,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),

                ],
              ),
            ),
    );
  }

  void _viewApplications(Property property) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.92,
          minChildSize: 0.45,
          expand: false,
          builder: (context, scrollController) {
            return ApplicationsBottomSheet(property: property, scrollController: scrollController);
          },
        );
      },
    );
  }
}

class _LandlordCardSkeleton extends StatelessWidget {
  const _LandlordCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceRaised,
      highlightColor: Colors.white.withValues(alpha: 0.08),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class ApplicationsBottomSheet extends StatefulWidget {
  final Property property;
  final ScrollController scrollController;

  const ApplicationsBottomSheet({
    super.key,
    required this.property,
    required this.scrollController,
  });

  @override
  State<ApplicationsBottomSheet> createState() => _ApplicationsBottomSheetState();
}

class _ApplicationsBottomSheetState extends State<ApplicationsBottomSheet> {
  List<dynamic> _applications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchApplications();
  }

  Future<void> _fetchApplications() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiService.get('/api/applications/property/${widget.property.id}');
      if (!mounted) return;
      setState(() {
        _applications = list as List;
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

  Future<void> _updateStatus(int id, String status) async {
    try {
      await ApiService.put('/api/applications/$id/status', {'status': status});
      if (!mounted) return;
      HapticFeedback.lightImpact();
      _fetchApplications();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Handle bar
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.assignment_ind_outlined, color: AppColors.accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rental Applications',
                      style: AppTextStyles.title.copyWith(color: Colors.white, fontSize: 17),
                    ),
                    Text(
                      widget.property.title,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(color: AppColors.border, height: 1),
        Expanded(
          child: _loading
              ? _buildBottomSheetSkeleton()
              : _error != null
                  ? Center(
                      child: Text(
                        'Error: $_error',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    )
                  : _applications.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inbox_outlined, color: AppColors.textTertiary, size: 48),
                              const SizedBox(height: 12),
                              Text(
                                'No applications submitted yet',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: widget.scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _applications.length,
                          itemBuilder: (context, index) {
                            final app = _applications[index];
                            final status = app['status'] ?? 'PENDING';
                            final monthlyIncome = app['monthlyIncome'] ?? 0.0;
                            final nationalId = app['nationalId'] ?? 'N/A';
                            final employment = app['employmentStatus'] ?? 'N/A';
                            final fullName = app['fullName'] ?? 'Applicant';
                            final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : 'A';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceRaised,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                                        child: Text(
                                          initial,
                                          style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              fullName,
                                              style: AppTextStyles.body.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              'Employment: $employment',
                                              style: AppTextStyles.caption.copyWith(
                                                color: AppColors.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      _buildApplicationStatusBadge(status),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'National ID: $nationalId',
                                        style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary, fontSize: 12),
                                      ),
                                      Text(
                                        'Income: ${CountryService.price(monthlyIncome)}',
                                        style: AppTextStyles.body.copyWith(
                                          color: AppColors.accent,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (status == 'PENDING') ...[
                                    const SizedBox(height: 14),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton(
                                          onPressed: () => _updateStatus(app['id'], 'REJECTED'),
                                          style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                                          child: const Text('Reject'),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          onPressed: () => _updateStatus(app['id'], 'APPROVED'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: Colors.black,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildBottomSheetSkeleton() {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceRaised,
      highlightColor: Colors.white.withValues(alpha: 0.08),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildApplicationStatusBadge(String status) {
    Color bg;
    Color fg;
    if (status == 'APPROVED') {
      bg = const Color(0xFF10B981).withValues(alpha: 0.15);
      fg = const Color(0xFF10B981);
    } else if (status == 'REJECTED') {
      bg = Colors.red.withValues(alpha: 0.15);
      fg = Colors.redAccent;
    } else {
      bg = Colors.amber.withValues(alpha: 0.15);
      fg = Colors.amber;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
