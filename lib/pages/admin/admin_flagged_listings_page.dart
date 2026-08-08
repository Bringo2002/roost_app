import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/country_service.dart';

/// Admin-only screen for reviewing listings with report activity. Shows
/// every listing with at least one unreviewed report (see
/// PropertyService.getFlaggedForReview) -- not just ones that crossed
/// the auto-hide threshold, since a single credible report is worth a
/// human look even below that bar. A listing here may still be
/// PUBLISHED (reported but not yet hidden) or already UNDER_REVIEW
/// (auto-hidden or manually hidden) -- the available actions differ
/// accordingly.
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
                          final hidden = property.status == 'UNDER_REVIEW';
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
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: (hidden ? Colors.redAccent : Colors.amber).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              hidden ? 'Hidden' : 'Still live',
                                              style: TextStyle(
                                                color: hidden ? Colors.redAccent : Colors.amber,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${property.reportCount} report${property.reportCount == 1 ? '' : 's'}',
                                            style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                          ),
                                        ],
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

  Future<void> _hide() async {
    setState(() => _submitting = true);
    try {
      await ApiService.post('/api/admin/properties/${widget.property.id}/hide');
      widget.onResolved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not hide: $e')),
      );
    }
  }

  Future<void> _dismiss() async {
    setState(() => _submitting = true);
    try {
      await ApiService.post('/api/admin/properties/${widget.property.id}/dismiss-reports');
      widget.onResolved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not dismiss: $e')),
      );
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Delete Listing', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This permanently removes the listing. This is separate from hiding it -- use this only for genuinely bad listings, not ones where the reports were just a judgment call.',
          style: TextStyle(color: Colors.white70),
        ),
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
    if (confirm != true) return;

    setState(() => _submitting = true);
    try {
      await ApiService.delete('/api/properties/${widget.property.id}');
      widget.onResolved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete: $e')),
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
              if (widget.property.status == 'UNDER_REVIEW')
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
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting ? null : _dismiss,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Dismiss'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _hide,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _submitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Hide Listing', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _submitting ? null : _delete,
                  child: Text('Delete listing permanently', style: TextStyle(color: Colors.red[300], fontSize: 12)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
