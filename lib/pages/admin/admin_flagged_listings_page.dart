import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/country_service.dart';

/// Admin-only screen for reviewing listings that were automatically
/// hidden after crossing the community-report threshold (see
/// PropertyService.reportProperty on the backend). Lets an admin see
/// who reported a listing and why, then either restore it to public
/// view or leave it hidden pending further action.
class AdminFlaggedListingsPage extends StatefulWidget {
  const AdminFlaggedListingsPage({super.key});

  @override
  State<AdminFlaggedListingsPage> createState() => _AdminFlaggedListingsPageState();
}

class _AdminFlaggedListingsPageState extends State<AdminFlaggedListingsPage> {
  List<Property> _flagged = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFlagged();
  }

  Future<void> _loadFlagged() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final jsonList = await ApiService.get('/api/admin/flagged-listings');
      if (!mounted) return;
      setState(() {
        _flagged = (jsonList as List).map((j) => Property.fromJson(j)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  void _openReports(Property property) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ReportsSheet(
        property: property,
        onResolved: () {
          Navigator.pop(ctx);
          _loadFlagged();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Flagged Listings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Failed to load: $_error', style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadFlagged, child: const Text('Retry')),
                    ],
                  ),
                )
              : _flagged.isEmpty
                  ? Center(
                      child: Text('No listings are currently flagged.', style: TextStyle(color: Colors.grey[500])),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadFlagged,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _flagged.length,
                        itemBuilder: (context, index) {
                          final property = _flagged[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: property.imageUrl != null
                                      ? Image.network(property.imageUrl!, width: 60, height: 60, fit: BoxFit.cover)
                                      : Container(width: 60, height: 60, color: Colors.grey[800]),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        property.title,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${property.location} · ${CountryService.price(property.price)}',
                                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _openReports(property),
                                  child: const Text('Review', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _ReportsSheet extends StatefulWidget {
  final Property property;
  final VoidCallback onResolved;

  const _ReportsSheet({required this.property, required this.onResolved});

  @override
  State<_ReportsSheet> createState() => _ReportsSheetState();
}

class _ReportsSheetState extends State<_ReportsSheet> {
  List<dynamic> _reports = [];
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      final result = await ApiService.get('/api/admin/properties/${widget.property.id}/reports');
      if (!mounted) return;
      setState(() {
        _reports = result as List;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load reports: $e')),
      );
    }
  }

  Future<void> _resolve(bool restore) async {
    setState(() => _submitting = true);
    try {
      await ApiService.post(
        '/api/admin/properties/${widget.property.id}/resolve-report',
        {'restore': restore},
      );
      widget.onResolved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not resolve: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.property.title,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('${_reports.length} report${_reports.length == 1 ? '' : 's'}', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _reports.length,
                        itemBuilder: (context, index) {
                          final r = _reports[index];
                          final reason = r['reason'] ?? 'Unspecified issue';
                          final details = r['details'];
                          final reporterName = r['reportedBy']?['name'] ?? 'Unknown user';
                          final createdAt = r['createdAt'] != null ? DateTime.tryParse(r['createdAt']) : null;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(reason, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                    ),
                                    if (createdAt != null)
                                      Text(DateFormat('dd MMM').format(createdAt), style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                                  ],
                                ),
                                if (details != null && details.toString().trim().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(details.toString(), style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                                ],
                                const SizedBox(height: 4),
                                Text('Reported by $reporterName', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting ? null : () => _resolve(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Keep Hidden'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitting ? null : () => _resolve(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _submitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Restore Listing', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
