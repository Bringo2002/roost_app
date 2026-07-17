import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/models/property.dart';

class LandlordDashboardPage extends StatefulWidget {
  const LandlordDashboardPage({super.key});

  @override
  State<LandlordDashboardPage> createState() => _LandlordDashboardPageState();
}

class _LandlordDashboardPageState extends State<LandlordDashboardPage> {
  List<Property> _myListings = [];
  bool _loading = true;
  int _totalListings = 0;
  int _totalSecured = 0;
  double _totalRevenue = 0.0;

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
      final stats = await ApiService.get('/api/verification/landlord-stats');
      if (!mounted) return;
      setState(() {
        _myListings = (jsonList as List).map((j) => Property.fromJson(j)).toList();
        _totalListings = stats['totalListings'] ?? 0;
        _totalSecured = stats['totalSecured'] ?? 0;
        _totalRevenue = (stats['totalRevenue'] ?? 0.0).toDouble();
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
    final updated = Property(
      id: property.id,
      title: property.title,
      description: property.description,
      location: property.location,
      price: property.price,
      bedrooms: property.bedrooms,
      type: property.type,
      landlordPhone: property.landlordPhone,
      available: !property.available,
      imageUrl: property.imageUrl,
      verified: property.verified,
      holdingFeePaid: property.holdingFeePaid,
      latitude: property.latitude,
      longitude: property.longitude,
      imageUrls: property.imageUrls,
    );

    try {
      await ApiService.put('/api/properties/${property.id}', updated.toJson());
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

  Widget _buildStatsHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'REVENUE SUMMARY',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('Total Earnings', 'KES ${NumberFormat('#,##0').format(_totalRevenue)}'),
              _buildStatItem('Secured', '$_totalSecured'),
              _buildStatItem('Listings', '$_totalListings'),
            ],
          ),
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
                                    child: Text(
                                      property.title,
                                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                        onPressed: () => _deleteListing(property),
                                      ),
                                      Switch(
                                        value: property.available,
                                        activeColor: Colors.white,
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
                                    'KES ${NumberFormat('#,##0').format(property.price)}',
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
                                  if (property.holdingFeePaid) ...[
                                    const Icon(Icons.check_circle_outline, color: Colors.white70, size: 18),
                                    const SizedBox(width: 8),
                                    const Text('SECURED', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed: () => _viewApplicants(property),
                                      style: TextButton.styleFrom(foregroundColor: Colors.white, padding: EdgeInsets.zero),
                                      child: const Text('View Payment', style: TextStyle(fontSize: 12)),
                                    ),
                                  ] else ...[
                                    const Icon(Icons.info_outline, color: Colors.white38, size: 18),
                                    const SizedBox(width: 8),
                                    const Text('NO HOLDING FEE', style: TextStyle(color: Colors.white38, fontSize: 13)),
                                  ],
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () => _viewApplications(property),
                                    style: TextButton.styleFrom(foregroundColor: Colors.white, padding: EdgeInsets.zero),
                                    child: const Text('Applications', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
    );
  }

  void _viewApplicants(Property property) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return FutureBuilder<List<dynamic>>(
          future: ApiService.get('/api/verification/property/${property.id}').then((val) => val as List),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator(color: Colors.white)),
              );
            }
            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                height: 200,
                child: const Center(child: Text('No payment records found', style: TextStyle(color: Colors.grey))),
              );
            }

            final payments = snapshot.data!;
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payment Details', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ...payments.map((p) {
                    final receipt = p['mpesaReceiptNumber'] ?? '';
                    final phone = p['tenantPhone'] ?? '';
                    final dateStr = p['createdAt'] != null
                        ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(p['createdAt']))
                        : '';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildRow('M-Pesa Receipt', receipt),
                        _buildRow('Tenant Phone', phone),
                        _buildRow('Timestamp', dateStr),
                        _buildRow('Amount', 'KES 2,000'),
                      ],
                    );
                  }).toList(),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(val, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
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
                                                  ? Colors.green.withOpacity(0.2)
                                                  : status == 'REJECTED'
                                                      ? Colors.red.withOpacity(0.2)
                                                      : Colors.amber.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              status,
                                              style: TextStyle(
                                                color: status == 'APPROVED'
                                                    ? Colors.green
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
                                      Text('Income: KES ${NumberFormat('#,##0').format(monthlyIncome)}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
