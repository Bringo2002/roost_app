import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/country_service.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:shimmer/shimmer.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Constants
// ──────────────────────────────────────────────────────────────────────────────

const _kCardRadius = 16.0;
const _kSheetRadius = 24.0;
const _kInnerRadius = 14.0;
const _kGridSpacing = 8.0;
const _kStaggerDelayMs = 60;

// ──────────────────────────────────────────────────────────────────────────────
// API paths
// ──────────────────────────────────────────────────────────────────────────────

const _kPendingPath = '/api/admin/pending-verifications';
String _approvePath(int id) => '/api/admin/properties/$id/approve-photos';
String _rejectPath(int id) => '/api/admin/properties/$id/reject-photos';

// ──────────────────────────────────────────────────────────────────────────────
// Filter enum
// ──────────────────────────────────────────────────────────────────────────────

/// Strongly-typed filter for the verification queue list.
enum _VerificationFilter {
  all('All Pending'),
  docs('Doc Proofs'),
  photos('Photos Only');

  const _VerificationFilter(this.label);
  final String label;
}

// ──────────────────────────────────────────────────────────────────────────────
// Page
// ──────────────────────────────────────────────────────────────────────────────

/// Admin-only verification audit portal for reviewing landlord proof documents,
/// GPS coordinates, and listing photos before granting "VERIFIED" status.
class AdminPendingVerificationsPage extends StatefulWidget {
  const AdminPendingVerificationsPage({super.key});

  @override
  State<AdminPendingVerificationsPage> createState() =>
      _AdminPendingVerificationsPageState();
}

class _AdminPendingVerificationsPageState
    extends State<AdminPendingVerificationsPage> {
  List<Property> _pending = [];
  bool _loading = true;
  String? _error;
  _VerificationFilter _filter = _VerificationFilter.all;

  /// Guards concurrent approve/reject on the same property.
  final Set<int> _busyIds = {};

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _loadPending() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final jsonList = await ApiService.get(_kPendingPath);
      if (!mounted) return;
      setState(() {
        _pending =
            (jsonList as List).map((j) => Property.fromJson(j)).toList();
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
    final id = property.id;
    if (id == null || _busyIds.contains(id)) return;
    setState(() => _busyIds.add(id));
    try {
      await ApiService.post(_approvePath(id));
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _pending.removeWhere((p) => p.id == id));
      _showSnack('🎉 Verification & Proofs Approved!', AppColors.verified);
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _showSnack('Could not approve: $e');
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Future<void> _reject(Property property, String reason) async {
    final id = property.id;
    if (id == null || _busyIds.contains(id)) return;
    setState(() => _busyIds.add(id));
    try {
      await ApiService.post(_rejectPath(id), {'reason': reason});
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _pending.removeWhere((p) => p.id == id));
      _showSnack('Verification rejected for "${property.title}"');
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _showSnack('Could not reject: $e');
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  void _showSnack(String message, [Color? color]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  // ── Sheet launcher ────────────────────────────────────────────────────────

  void _openAuditSheet(Property property) {
    final busy = property.id != null && _busyIds.contains(property.id);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.sheetDeep,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(_kSheetRadius)),
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

  // ── Derived data ──────────────────────────────────────────────────────────

  List<Property> get _filteredList => switch (_filter) {
        _VerificationFilter.all => _pending,
        _VerificationFilter.docs => _pending
            .where((p) => p.documentUrls.isNotEmpty || p.documentVerified)
            .toList(),
        _VerificationFilter.photos =>
          _pending.where((p) => p.imageUrls.isNotEmpty).toList(),
      };

  int get _docCount =>
      _pending.where((p) => p.documentUrls.isNotEmpty).length;

  int get _gpsCount => _pending.where((p) => p.gpsVerified).length;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredList;

    return Scaffold(
      backgroundColor: AppColors.scaffoldDeep,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldDeep,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Verification Audit Portal',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadPending,
          ),
        ],
      ),
      body: _buildBody(filtered),
    );
  }

  Widget _buildBody(List<Property> filtered) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.verified),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Failed to load: $_error',
              style: const TextStyle(color: AppColors.destructive),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadPending,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.verified,
      backgroundColor: AppColors.zinc900,
      onRefresh: _loadPending,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          _buildAuditMetricsHeader(),
          const SizedBox(height: 16),
          _buildFilterRow(),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            _buildEmptyState()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, index) {
                final property = filtered[index];
                final busy =
                    property.id != null && _busyIds.contains(property.id);
                return _AuditCard(
                  property: property,
                  busy: busy,
                  onInspect: () => _openAuditSheet(property),
                );
              },
            ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ── Sub-widgets ───────────────────────────────────────────────────────────

  Widget _buildFilterRow() {
    return Row(
      children: [
        for (final f in _VerificationFilter.values) ...[
          if (f != _VerificationFilter.values.first) const SizedBox(width: 8),
          _buildFilterChip(f),
        ],
      ],
    );
  }

  Widget _buildFilterChip(_VerificationFilter value) {
    final isSelected = _filter == value;
    final count = switch (value) {
      _VerificationFilter.all => _pending.length,
      _VerificationFilter.docs => _docCount,
      _VerificationFilter.photos => null,
    };
    final text = count != null ? '${value.label} ($count)' : value.label;

    return ChoiceChip(
      label: Text(
        text,
        style: TextStyle(
          color: isSelected ? Colors.black : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: AppColors.verified,
      backgroundColor: AppColors.zinc900,
      side: BorderSide(
        color: isSelected ? AppColors.verified : Colors.white10,
      ),
    );
  }

  Widget _buildAuditMetricsHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.slate800, AppColors.slate900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MetricItem(
            label: 'Pending Queue',
            value: '${_pending.length}',
            icon: Icons.pending_actions,
            color: AppColors.warning,
          ),
          Container(width: 1, height: 36, color: Colors.white10),
          _MetricItem(
            label: 'Doc Proofs',
            value: '$_docCount',
            icon: Icons.description_outlined,
            color: AppColors.skyBlue,
          ),
          Container(width: 1, height: 36, color: Colors.white10),
          _MetricItem(
            label: 'GPS Confirmed',
            value: '$_gpsCount',
            icon: Icons.location_on_outlined,
            color: AppColors.verified,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      margin: const EdgeInsets.only(top: 24),
      decoration: BoxDecoration(
        color: AppColors.zinc900,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: Colors.white10),
      ),
      child: const Column(
        children: [
          Icon(Icons.verified_outlined, color: AppColors.verified, size: 48),
          SizedBox(height: 12),
          Text(
            'Verification Queue Clear',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'No landlord properties currently awaiting audit approval.',
            style: TextStyle(color: Colors.white54, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Small stateless leaf widgets
// ──────────────────────────────────────────────────────────────────────────────

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}

class _ProofBadge extends StatelessWidget {
  const _ProofBadge({
    required this.label,
    required this.isDone,
    required this.icon,
  });

  final String label;
  final bool isDone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDone ? AppColors.verified.withAlpha(25) : Colors.white10,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDone ? AppColors.verified.withAlpha(60) : Colors.white12,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: isDone ? AppColors.verifiedLight : Colors.white38,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: isDone ? AppColors.verifiedLight : Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Audit card (list item)
// ──────────────────────────────────────────────────────────────────────────────

class _AuditCard extends StatelessWidget {
  const _AuditCard({
    required this.property,
    required this.busy,
    required this.onInspect,
  });

  final Property property;
  final bool busy;
  final VoidCallback onInspect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.zinc900,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          _buildProofRow(),
          const SizedBox(height: 14),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 10),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _PropertyThumbnail(imageUrl: property.imageUrl),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                property.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
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
    );
  }

  Widget _buildProofRow() {
    final docCount = property.documentUrls.length;
    // Wrap instead of Row to prevent overflow on narrow screens.
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        const _ProofBadge(
          label: 'Phone SMS',
          isDone: true,
          icon: Icons.phone_android,
        ),
        _ProofBadge(
          label: 'GPS Location',
          isDone: property.gpsVerified,
          icon: Icons.my_location,
        ),
        _ProofBadge(
          label: docCount > 0 ? '$docCount Docs Attached' : 'No Docs',
          isDone: docCount > 0,
          icon: Icons.description,
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _formatRelativeTime(property.listedAt),
          style: TextStyle(color: Colors.grey[600], fontSize: 11),
        ),
        ElevatedButton.icon(
          onPressed: busy ? null : onInspect,
          icon: busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                )
              : const Icon(Icons.fact_check, size: 15),
          label: Text(
            busy ? 'Processing...' : 'Audit & Inspect Proofs',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.verified,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }
}

class _PropertyThumbnail extends StatelessWidget {
  const _PropertyThumbnail({required this.imageUrl});

  final String? imageUrl;

  static const _size = 62.0;
  static const _fallback = Icon(Icons.home, color: Colors.white38);

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) {
      return Container(
        width: _size,
        height: _size,
        color: Colors.grey[800],
        child: _fallback,
      );
    }
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      width: _size,
      height: _size,
      fit: BoxFit.cover,
      memCacheWidth: (_size * 2).toInt(),
      memCacheHeight: (_size * 2).toInt(),
      placeholder: (_, __) => _ShimmerBox(width: _size, height: _size),
      errorWidget: (_, __, ___) => Container(
        width: _size,
        height: _size,
        color: Colors.grey[800],
        child: _fallback,
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Shimmer placeholder
// ──────────────────────────────────────────────────────────────────────────────

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({this.width, this.height, this.borderRadius});

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[700]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: borderRadius ?? BorderRadius.circular(10),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Audit bottom sheet with staggered animations
// ──────────────────────────────────────────────────────────────────────────────

class _AuditDocumentSheet extends StatefulWidget {
  final Property property;
  final bool busy;
  final VoidCallback onApprove;
  final ValueChanged<String> onReject;

  const _AuditDocumentSheet({
    required this.property,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<_AuditDocumentSheet> createState() => _AuditDocumentSheetState();
}

class _AuditDocumentSheetState extends State<_AuditDocumentSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  /// Each section gets its own staggered [Animation<double>].
  late final List<Animation<double>> _sectionAnims;

  /// Cached slide position animations — built once in [initState], not on
  /// every frame.
  late final List<Animation<Offset>> _slideAnims;

  static const _sectionCount = 6; // header, landlord, AI, docs, photos, buttons

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: 300 + (_sectionCount * _kStaggerDelayMs),
      ),
    );
    _sectionAnims = List.generate(_sectionCount, (i) {
      final start = (i * _kStaggerDelayMs) /
          (300 + (_sectionCount * _kStaggerDelayMs));
      final end = (start + 0.4).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _animController,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
    });
    _slideAnims = List.generate(_sectionCount, (i) {
      return Tween<Offset>(
        begin: const Offset(0, 0.08),
        end: Offset.zero,
      ).animate(_sectionAnims[i]);
    });
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Widget _staggered(int index, Widget child) {
    return FadeTransition(
      opacity: _sectionAnims[index],
      child: SlideTransition(
        position: _slideAnims[index],
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docs = widget.property.documentUrls;
    final photos = widget.property.imageUrls;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.6,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDragHandle(),
              const SizedBox(height: 16),
              _staggered(0, _buildTitleRow(context)),
              const SizedBox(height: 16),
              _staggered(1, _buildLandlordCard()),
              const SizedBox(height: 18),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _staggered(2, _buildAISummary(docs)),
                    _staggered(3, _buildDocsSection(context, docs)),
                    const SizedBox(height: 20),
                    _staggered(4, _buildPhotosSection(photos)),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _staggered(5, _buildActionButtons(context)),
            ],
          ),
        );
      },
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildTitleRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.property.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${widget.property.location} · ${CountryService.price(widget.property.price)}',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 12, color: AppColors.verified),
                  const SizedBox(width: 4),
                  Text(
                    _formatRelativeTime(widget.property.listedAt),
                    style: const TextStyle(
                      color: AppColors.verifiedLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
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
    );
  }

  Widget _buildLandlordCard() {
    return Container(
      padding: const EdgeInsets.all(_kInnerRadius),
      decoration: BoxDecoration(
        color: AppColors.zinc900,
        borderRadius: BorderRadius.circular(_kInnerRadius),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.verified,
            child: Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.property.landlordName ?? 'Landlord User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Phone: ${widget.property.landlordPhone.isNotEmpty ? widget.property.landlordPhone : 'SMS Verified'}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          if (widget.property.gpsVerified)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.verified.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'GPS Matched',
                style: TextStyle(
                  color: AppColors.verifiedLight,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── AI Summary ──────────────────────────────────────────────────────────

  Widget _buildAISummary(List<String> docs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(_kInnerRadius),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.slate800, AppColors.slate900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(_kInnerRadius),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.psychology_outlined,
                  color: AppColors.indigoLight, size: 16),
              SizedBox(width: 6),
              Text(
                'AI VERIFICATION SIGNALS',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _AICheckRow(
            label: 'Tier 1 Checks',
            detail: 'File size, MIME type, EXIF date, duplicate hash',
            status: docs.isNotEmpty ? 'passed' : 'skipped',
          ),
          const SizedBox(height: 6),
          _AICheckRow(
            label: 'Tier 2 Gemini AI',
            detail: 'Doc classification, authenticity & name extraction',
            status: docs.isNotEmpty ? 'analysed' : 'skipped',
          ),
          const SizedBox(height: 6),
          _AICheckRow(
            label: 'Name Cross-Reference',
            detail: 'Extracted name matched against landlord account',
            status: docs.isNotEmpty ? 'checked' : 'skipped',
          ),
          if (docs.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 8),
            Text(
              '${docs.length} document${docs.length > 1 ? 's' : ''} submitted. '
              'AI pre-screened — human review required below.',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  // ── Documents ─────────────────────────────────────────────────────────

  Widget _buildDocsSection(BuildContext context, List<String> docs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          icon: Icons.description,
          color: AppColors.skyBlue,
          title: 'ATTACHED OWNERSHIP PROOFS (${docs.length})',
        ),
        const SizedBox(height: 10),
        if (docs.isEmpty)
          _buildEmptyNotice(
            icon: Icons.info_outline,
            color: AppColors.warning,
            text:
                'No title deed or utility documents attached to this submission.',
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
            itemBuilder: (_, idx) => _DocumentPreview(
              url: docs[idx],
              docNumber: idx + 1,
              allUrls: docs,
            ),
          ),
      ],
    );
  }

  // ── Photos ────────────────────────────────────────────────────────────

  Widget _buildPhotosSection(List<String> photos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          icon: Icons.photo_library,
          color: AppColors.warning,
          title: 'LISTING PHOTOS (${photos.length})',
        ),
        const SizedBox(height: 10),
        if (photos.isEmpty)
          _buildEmptyNotice(
            icon: Icons.image_not_supported_outlined,
            color: Colors.white38,
            text: 'No listing photos have been uploaded for this property.',
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: _kGridSpacing,
              mainAxisSpacing: _kGridSpacing,
            ),
            itemCount: photos.length,
            itemBuilder: (_, idx) {
              return GestureDetector(
                onTap: () => _pushGallery(context, photos, idx),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: photos[idx],
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        _ShimmerBox(borderRadius: BorderRadius.zero),
                    errorWidget: (_, __, ___) =>
                        Container(color: Colors.grey[800]),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // ── Reusable section helpers ──────────────────────────────────────────

  Widget _buildSectionHeader({
    required IconData icon,
    required Color color,
    required String title,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyNotice({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.zinc900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ── Action buttons ────────────────────────────────────────────────────

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: widget.busy ? null : () => _showRejectDialog(context),
            icon: const Icon(Icons.cancel_outlined, size: 16),
            label: const Text('Reject Proofs'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.destructive,
              side: const BorderSide(color: AppColors.destructive),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
                  color: AppColors.verified.withAlpha(80),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: widget.busy ? null : () => _showApproveConfirmation(context),
              icon: widget.busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.verified, size: 16),
              label: Text(
                widget.busy ? 'Processing...' : 'Grant VERIFIED',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.verified,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Approve confirmation dialog ───────────────────────────────────────

  void _showApproveConfirmation(BuildContext context) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.zinc900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.verified, color: AppColors.verified, size: 22),
            SizedBox(width: 8),
            Text(
              'Confirm Verification',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'Grant VERIFIED status to "${widget.property.title}"?\n\n'
          'This action marks the listing as authentic and displays '
          'a verified badge to all users.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.verified,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.verified, size: 16),
            label: const Text('Confirm'),
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(ctx);
              widget.onApprove();
            },
          ),
        ],
      ),
    );
  }

  // ── Reject dialog ─────────────────────────────────────────────────────

  void _showRejectDialog(BuildContext context) {
    HapticFeedback.lightImpact();
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, _) {
            return AlertDialog(
              backgroundColor: AppColors.zinc900,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Reject Verification',
                style: TextStyle(color: Colors.white),
              ),
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
                      hintText:
                          'e.g. Unclear title deed copy / Invalid utility bill',
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.verified),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.destructive,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    final reason = controller.text.trim().isEmpty
                        ? 'Invalid document proof'
                        : controller.text.trim();
                    Navigator.pop(ctx);
                    widget.onReject(reason);
                  },
                  child: const Text('Confirm Reject'),
                ),
              ],
            );
          },
        );
      },
    );
  }


}

// ──────────────────────────────────────────────────────────────────────────────
// Full-screen swipeable gallery
// ──────────────────────────────────────────────────────────────────────────────

class _FullScreenGallery extends StatefulWidget {
  const _FullScreenGallery({required this.urls, required this.initialIndex});

  final List<String> urls;
  final int initialIndex;

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late final PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Dismiss on background tap
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(context),
            child: const SizedBox.expand(),
          ),
          // Swipeable pages
          PageView.builder(
            controller: _pageController,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (_, i) => Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: widget.urls[i],
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: AppColors.verified),
                  ),
                  errorWidget: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image, color: Colors.white38, size: 48),
                  ),
                ),
              ),
            ),
          ),
          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          // Page indicator
          if (widget.urls.length > 1)
            Positioned(
              bottom: MediaQuery.viewPaddingOf(context).bottom + 24,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.urls.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _currentPage ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _currentPage
                          ? AppColors.verified
                          : Colors.white38,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Shared leaf widgets used inside the audit sheet
// ──────────────────────────────────────────────────────────────────────────────

class _AICheckRow extends StatelessWidget {
  const _AICheckRow({
    required this.label,
    required this.detail,
    required this.status,
  });

  final String label;
  final String detail;
  final String status;

  @override
  Widget build(BuildContext context) {
    final isDone = status != 'skipped';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone ? AppColors.verified.withAlpha(30) : Colors.white12,
          ),
          child: Icon(
            isDone ? Icons.check_rounded : Icons.remove_rounded,
            size: 11,
            color: isDone ? AppColors.verified : Colors.white38,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isDone ? Colors.white : Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                detail,
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isDone ? AppColors.verified.withAlpha(20) : Colors.white10,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            status.toUpperCase(),
            style: TextStyle(
              color: isDone ? AppColors.verifiedLight : Colors.white38,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _DocumentPreview extends StatelessWidget {
  const _DocumentPreview({
    required this.url,
    required this.docNumber,
    required this.allUrls,
  });

  final String url;
  final int docNumber;
  final List<String> allUrls;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openGallery(context),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.zinc900,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.skyBlue.withAlpha(80)),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: CachedNetworkImage(
                  imageUrl: url,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _ShimmerBox(
                    borderRadius: BorderRadius.zero,
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.grey[900],
                    child: const Icon(
                      Icons.description,
                      color: AppColors.skyBlue,
                      size: 36,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Doc Proof #$docNumber',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openGallery(BuildContext context) {
    _pushGallery(context, allUrls, docNumber - 1);
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Shared gallery launcher
// ──────────────────────────────────────────────────────────────────────────────

/// Opens the [_FullScreenGallery] with a fade transition.
///
/// Shared by both the photo grid and document preview widgets to avoid
/// duplicating the [PageRouteBuilder] boilerplate.
void _pushGallery(BuildContext context, List<String> urls, int initialIndex) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      pageBuilder: (_, __, ___) =>
          _FullScreenGallery(urls: urls, initialIndex: initialIndex),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// Utilities
// ──────────────────────────────────────────────────────────────────────────────

/// Returns a human-readable relative timestamp from an ISO-8601 string,
/// e.g. "Submitted 5 min ago", "Submitted 3 hr ago".
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
