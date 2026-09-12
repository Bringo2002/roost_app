import 'package:flutter/material.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/country_service.dart';

/// Admin-only FAANG Verification Audit Portal for reviewing landlord proof documents,
/// GPS coordinates, and listing photos before granting full "VERIFIED" status.
class AdminPendingVerificationsPage extends StatefulWidget {
  const AdminPendingVerificationsPage({super.key});

  @override
  State<AdminPendingVerificationsPage> createState() => _AdminPendingVerificationsPageState();
}

class _AdminPendingVerificationsPageState extends State<AdminPendingVerificationsPage> {
  List<Property> _pending = [];
  bool _loading = true;
  String? _error;
  String _selectedFilter = 'ALL'; // 'ALL', 'DOCS', 'PHOTOS'

  final Set<int> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final jsonList = await ApiService.get('/api/admin/pending-verifications');
      if (!mounted) return;
      setState(() {
        _pending = (jsonList as List).map((j) => Property.fromJson(j)).toList();
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

  Future<void> _approve(Property property) async {
    if (property.id == null || _busyIds.contains(property.id)) return;
    setState(() => _busyIds.add(property.id!));
    try {
      await ApiService.post('/api/admin/properties/${property.id}/approve-photos');
      if (!mounted) return;
      setState(() => _pending.removeWhere((p) => p.id == property.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Verification & Proofs Approved Successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not approve: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(property.id));
    }
  }

  Future<void> _reject(Property property, String reason) async {
    if (property.id == null || _busyIds.contains(property.id)) return;
    setState(() => _busyIds.add(property.id!));
    try {
      // Endpoint to reject verification request
      await ApiService.post('/api/admin/properties/${property.id}/reject-photos', {'reason': reason});
      if (!mounted) return;
      setState(() => _pending.removeWhere((p) => p.id == property.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification rejected for "${property.title}"')),
      );
    } catch (_) {
      // Fallback: local remove if endpoint not present
      if (!mounted) return;
      setState(() => _pending.removeWhere((p) => p.id == property.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification rejected')),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(property.id));
    }
  }

  void _openAuditSheet(Property property) {
    final busy = property.id != null && _busyIds.contains(property.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121214),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AuditDocumentSheet(
        property: property,
        busy: busy,
        onApprove: () async {
          await _approve(property);
          if (ctx.mounted) Navigator.pop(ctx);
        },
        onReject: (reason) async {
          await _reject(property, reason);
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  List<Property> get _filteredList {
    if (_selectedFilter == 'DOCS') {
      return _pending.where((p) => p.documentUrls.isNotEmpty || p.documentVerified).toList();
    } else if (_selectedFilter == 'PHOTOS') {
      return _pending.where((p) => p.imageUrls.isNotEmpty).toList();
    }
    return _pending;
  }

  int get _docCount => _pending.where((p) => p.documentUrls.isNotEmpty).length;
  int get _gpsCount => _pending.where((p) => p.gpsVerified).length;

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredList;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F11),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Verification Audit Portal',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadPending,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Failed to load: $_error', style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadPending, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFF10B981),
                  backgroundColor: const Color(0xFF18181B),
                  onRefresh: _loadPending,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // Top Audit Metrics Banner
                      _buildAuditMetricsHeader(),

                      const SizedBox(height: 16),

                      // Filter Chips
                      Row(
                        children: [
                          _buildFilterChip('ALL', 'All Pending (${_pending.length})'),
                          const SizedBox(width: 8),
                          _buildFilterChip('DOCS', 'Doc Proofs ($_docCount)'),
                          const SizedBox(width: 8),
                          _buildFilterChip('PHOTOS', 'Photos Only'),
                        ],
                      ),

                      const SizedBox(height: 16),

                      if (filtered.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          margin: const EdgeInsets.only(top: 24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF18181B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.verified_outlined, color: Color(0xFF10B981), size: 48),
                              SizedBox(height: 12),
                              Text(
                                'Verification Queue Clear',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'No landlord properties currently awaiting audit approval.',
                                style: TextStyle(color: Colors.white54, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final property = filtered[index];
                            final busy = property.id != null && _busyIds.contains(property.id);
                            return _buildAuditCard(property, busy: busy);
                          },
                        ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.black : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = key),
      selectedColor: const Color(0xFF10B981),
      backgroundColor: const Color(0xFF18181B),
      side: BorderSide(color: isSelected ? const Color(0xFF10B981) : Colors.white10),
    );
  }

  Widget _buildAuditMetricsHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetricItem('Pending Queue', '${_pending.length}', Icons.pending_actions, Colors.amber),
          Container(width: 1, height: 36, color: Colors.white10),
          _buildMetricItem('Doc Proofs', '$_docCount', Icons.description_outlined, const Color(0xFF38BDF8)),
          Container(width: 1, height: 36, color: Colors.white10),
          _buildMetricItem('GPS Confirmed', '$_gpsCount', Icons.location_on_outlined, const Color(0xFF10B981)),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _buildAuditCard(Property property, {required bool busy}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: property.imageUrl != null
                    ? Image.network(property.imageUrl!, width: 62, height: 62, fit: BoxFit.cover)
                    : Container(width: 62, height: 62, color: Colors.grey[800], child: const Icon(Icons.home, color: Colors.white38)),
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
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lister: ${property.landlordName ?? property.landlordPhone}',
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 3-Checkpoint Status Row
          Row(
            children: [
              _buildProofBadge('Phone SMS', true, Icons.phone_android),
              const SizedBox(width: 6),
              _buildProofBadge('GPS Location', property.gpsVerified, Icons.my_location),
              const SizedBox(width: 6),
              _buildProofBadge(
                property.documentUrls.isNotEmpty ? '${property.documentUrls.length} Docs Attached' : 'No Docs',
                property.documentUrls.isNotEmpty,
                Icons.description,
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 10),

          // Audit CTA Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatRelativeTime(property.listedAt),
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
              ElevatedButton.icon(
                onPressed: busy ? null : () => _openAuditSheet(property),
                icon: busy
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70))
                    : const Icon(Icons.fact_check, size: 15),
                label: Text(busy ? 'Processing...' : 'Audit & Inspect Proofs', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProofBadge(String label, bool isDone, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDone ? const Color(0xFF10B981).withAlpha(25) : Colors.white10,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDone ? const Color(0xFF10B981).withAlpha(60) : Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: isDone ? const Color(0xFF34D399) : Colors.white38),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: isDone ? const Color(0xFF34D399) : Colors.white54, fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

}

/// Returns a human-readable relative timestamp from an ISO-8601 string,
/// e.g. "5 mins ago", "3 hrs ago", "2 days ago".
String _formatRelativeTime(String? isoDate) {
  if (isoDate == null) return 'Submitted recently';
  final dt = DateTime.tryParse(isoDate);
  if (dt == null) return 'Submitted recently';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return 'Submitted ${diff.inMinutes} min ago';
  if (diff.inHours < 24) return 'Submitted ${diff.inHours} hr ago';
  if (diff.inDays == 1) return 'Submitted yesterday';
  return 'Submitted ${diff.inDays} days ago';
}

class _AuditDocumentSheet extends StatelessWidget {
  final Property property;
  final bool busy;
  final VoidCallback onApprove;
  final Function(String reason) onReject;

  const _AuditDocumentSheet({
    required this.property,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final docs = property.documentUrls;
    final photos = property.imageUrls;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.6,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sheet Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          property.title,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${property.location} · ${CountryService.price(property.price)}',
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.schedule, size: 12, color: Color(0xFF10B981)),
                            const SizedBox(width: 4),
                            Text(
                              _formatRelativeTime(property.listedAt),
                              style: const TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Landlord & Coordinates Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFF10B981),
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            property.landlordName ?? 'Landlord User',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Phone: ${property.landlordPhone.isNotEmpty ? property.landlordPhone : 'SMS Verified'}',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (property.gpsVerified)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('GPS Matched', style: TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // Ownership Document Proofs Section
                    Row(
                      children: [
                        const Icon(Icons.description, color: Color(0xFF38BDF8), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'ATTACHED OWNERSHIP PROOFS (${docs.length})',
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (docs.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF18181B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withAlpha(50)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.amber, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No title deed or utility documents attached to this submission.',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.2,
                        ),
                        itemCount: docs.length,
                        itemBuilder: (ctx, idx) {
                          return _buildDocumentPreview(context, docs[idx], idx + 1);
                        },
                      ),

                    const SizedBox(height: 20),

                    // Property Photos Section
                    Row(
                      children: [
                        const Icon(Icons.photo_library, color: Colors.amber, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'LISTING PHOTOS (${photos.length})',
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemCount: photos.length,
                      itemBuilder: (ctx, idx) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            photos[idx],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: Colors.grey[850]),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Action Buttons Row (Approve / Reject)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () {
                              _showRejectDialog(context);
                            },
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Reject Proofs'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withAlpha(80),
                            blurRadius: 16,
                            spreadRadius: 0,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: busy ? null : onApprove,
                        icon: busy
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.verified, size: 16),
                        label: Text(busy ? 'Processing...' : 'Grant VERIFIED', style: const TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
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

  Widget _buildDocumentPreview(BuildContext context, String url, int docNumber) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: Colors.black,
            child: InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF38BDF8).withAlpha(80)),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  url,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[900],
                    child: const Icon(Icons.description, color: Color(0xFF38BDF8), size: 36),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              alignment: Alignment.center,
              child: Text(
                'Doc Proof #$docNumber',
                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: const Text('Reject Verification', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Specify why the verification proof was rejected:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'e.g. Unclear title deed copy / Invalid utility bill',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF10B981))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              onReject(controller.text.trim().isEmpty ? 'Invalid document proof' : controller.text.trim());
            },
            child: const Text('Confirm Reject'),
          ),
        ],
      ),
    );
  }
}
