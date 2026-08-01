import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/country_service.dart';
import 'package:roost_app/services/location_service.dart';
import 'package:roost_app/pages/landlord/add_property_page.dart';

class LandlordDashboardPage extends StatefulWidget {
  const LandlordDashboardPage({super.key});

  @override
  State<LandlordDashboardPage> createState() => _LandlordDashboardPageState();
}

class _LandlordDashboardPageState extends State<LandlordDashboardPage> {
  List<Property> _myListings = [];
  bool _loading = true;

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

  Future<void> _toggleAvailability(Property property) async {
    if (property.id == null) return;

    // Marking rented is the more consequential direction (removes the
    // listing from discovery), so it gets a confirmation -- matching
    // the brief's "Tap Mark as Rented" as a deliberate action, not a
    // switch someone could flip by accident. Re-marking available
    // doesn't need the same friction.
    if (property.available) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Mark as Rented?', style: TextStyle(color: Colors.white)),
          content: const Text(
            'This listing will disappear from discovery. You can mark it available again anytime.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Mark as Rented'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    try {
      await ApiService.patch('/api/properties/${property.id}/availability', {
        'available': !property.available,
      });
      _loadListings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _deleteListing(Property property) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Delete Listing', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this listing?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && property.id != null) {
      try {
        await ApiService.delete('/api/properties/${property.id}');
        _loadListings();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  /// One-tap publish for a draft, without reopening the wizard. Backend
  /// still enforces phone verification (PropertyService.assertCanPublish)
  /// even though this shortcut skips the wizard's own verification UI --
  /// if that check fails, send the landlord into the wizard instead,
  /// where the phone-verification screen actually lives.
  /// Called when the landlord is physically at the property and taps
  /// the "verify location" prompt -- takes the device's live GPS
  /// reading and sends it to the backend, which independently checks
  /// the distance to the listing's pinned coordinates
  /// (PropertyService.verifyGpsLocation) rather than trusting a
  /// client-reported "yes I'm here."
  Future<void> _verifyGps(Property property) async {
    final position = await LocationService.getCurrentPosition();
    if (position == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not get your location. Check that location services are enabled.')),
      );
      return;
    }

    try {
      await ApiService.post('/api/properties/${property.id}/verify-gps', {
        'latitude': position.latitude,
        'longitude': position.longitude,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location verified')),
      );
      _loadListings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _publishDraft(Property property) async {
    try {
      await ApiService.patch('/api/properties/${property.id}/publish', {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listing published')),
      );
      _loadListings();
    } catch (e) {
      if (!mounted) return;
      final proceedToWizard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Could not publish', style: TextStyle(color: Colors.white)),
          content: Text(
            'This usually means your phone isn\'t verified yet. Open the listing to verify and publish?',
            style: TextStyle(color: Colors.grey[400]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Open Listing')),
          ],
        ),
      );
      if (proceedToWizard == true) {
        final updated = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => AddPropertyPage(editingProperty: property)),
        );
        if (updated == true) _loadListings();
      }
    }
  }

  Widget _buildStatsHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatItem('Listings', '${_myListings.length}'),
          _buildStatItem('Drafts', '${_myListings.where((p) => p.status == 'DRAFT').length}'),
          _buildStatItem('Available', '${_myListings.where((p) => p.available).length}'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('My Listings', style: TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : RefreshIndicator(
              color: Colors.white,
              backgroundColor: Colors.grey[900],
              onRefresh: _loadListings,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStatsHeader(),
                  if (_myListings.isEmpty)
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.business_center_outlined, color: Colors.grey[700], size: 64),
                            const SizedBox(height: 16),
                            Text(
                              'No properties listed yet',
                              style: TextStyle(color: Colors.grey[500], fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap the "+" button on Home feed to add one',
                              style: TextStyle(color: Colors.grey[700], fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._myListings.map((property) {
                      return Card(
                        color: Colors.grey[900],
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
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
                                        Flexible(
                                          child: Text(
                                            property.title,
                                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (property.status == 'DRAFT') ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.amber, width: 1),
                                            ),
                                            child: const Text(
                                              'DRAFT',
                                              style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                                        tooltip: 'Edit listing',
                                        onPressed: () async {
                                          final updated = await Navigator.push<bool>(
                                            context,
                                            MaterialPageRoute(builder: (_) => AddPropertyPage(editingProperty: property)),
                                          );
                                          if (updated == true) _loadListings();
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                        tooltip: 'Delete listing',
                                        onPressed: () => _deleteListing(property),
                                      ),
                                      Text(
                                        property.available ? 'Available' : 'Rented',
                                        style: TextStyle(
                                          color: property.available ? Colors.greenAccent : Colors.grey[500],
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Switch(
                                        value: property.available,
                                        activeThumbColor: Colors.white,
                                        activeTrackColor: Colors.grey[800],
                                        inactiveThumbColor: Colors.grey[600],
                                        inactiveTrackColor: Colors.grey[950],
                                        onChanged: (_) => _toggleAvailability(property),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Text(
                                property.location,
                                style: TextStyle(color: Colors.grey[500], fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    CountryService.price(property.price),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text(
                                    property.available ? 'AVAILABLE' : 'UNAVAILABLE',
                                    style: TextStyle(
                                      color: property.available ? Colors.white : Colors.grey[600],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(color: Colors.white12, height: 24),
                              Row(
                                children: [
                                  Text(
                                    property.status == 'DRAFT'
                                        ? 'Not published yet'
                                        : (property.listedAt != null
                                            ? 'Listed ${DateFormat('dd MMM yyyy').format(DateTime.parse(property.listedAt!))}'
                                            : 'Listed recently'),
                                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                                  ),
                                  const Spacer(),
                                  if (property.status == 'DRAFT')
                                    TextButton(
                                      onPressed: () => _publishDraft(property),
                                      style: TextButton.styleFrom(foregroundColor: Colors.amber, padding: EdgeInsets.zero),
                                      child: const Text('Publish', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    )
                                  else
                                    TextButton(
                                      onPressed: () => _viewApplications(property),
                                      style: TextButton.styleFrom(foregroundColor: Colors.white, padding: EdgeInsets.zero),
                                      child: const Text('Applications', style: TextStyle(fontSize: 12)),
                                    ),
                                ],
                              ),
                              if (property.status == 'PUBLISHED' && !property.gpsVerified) ...[
                                const SizedBox(height: 10),
                                GestureDetector(
                                  onTap: () => _verifyGps(property),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.location_searching, color: Colors.amber, size: 16),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Stand at the property and tap to verify location',
                                        style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  void _viewApplications(Property property) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return ApplicationsBottomSheet(property: property, scrollController: scrollController);
          },
        );
      },
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
      _fetchApplications();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Applications for ${widget.property.title}',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _error != null
                    ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.redAccent)))
                    : _applications.isEmpty
                        ? const Center(child: Text('No applications yet', style: TextStyle(color: Colors.white54)))
                        : ListView.builder(
                            controller: widget.scrollController,
                            itemCount: _applications.length,
                            itemBuilder: (context, index) {
                              final app = _applications[index];
                              final status = app['status'] ?? 'PENDING';
                              final monthlyIncome = app['monthlyIncome'] ?? 0.0;
                              final nationalId = app['nationalId'] ?? 'N/A';
                              final employment = app['employmentStatus'] ?? 'N/A';

                              return Card(
                                color: Colors.white10,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            app['fullName'] ?? 'Applicant',
                                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: status == 'APPROVED'
                                                  ? Colors.white.withValues(alpha: 0.15)
                                                  : status == 'REJECTED'
                                                      ? Colors.red.withValues(alpha: 0.2)
                                                      : Colors.amber.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              status,
                                              style: TextStyle(
                                                color: status == 'APPROVED'
                                                    ? Colors.white
                                                    : status == 'REJECTED'
                                                        ? Colors.red
                                                        : Colors.amber,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text('National ID: $nationalId', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                      Text('Employment: $employment', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                      Text('Income: ${CountryService.price(monthlyIncome)}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                      if (status == 'PENDING') ...[
                                        const SizedBox(height: 12),
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
                                              ),
                                              child: const Text('Approve'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
