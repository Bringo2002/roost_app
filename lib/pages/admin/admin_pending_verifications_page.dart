import 'package:flutter/material.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/country_service.dart';

/// Admin-only screen for reviewing listings awaiting photo sign-off.
/// These already have GPS and a confirmed phone (see
/// PropertyService.getPendingPhotoReview) -- photo approval is the last
/// gate before a listing shows as fully "Verified".
class AdminPendingVerificationsPage extends StatefulWidget {
  const AdminPendingVerificationsPage({super.key});

  @override
  State<AdminPendingVerificationsPage> createState() => _AdminPendingVerificationsPageState();
}

class _AdminPendingVerificationsPageState extends State<AdminPendingVerificationsPage> {
  List<Property> _pending = [];
  bool _loading = true;
  String? _error;

  /// Ids with an approve request in flight, so a slow round trip can't
  /// be double-tapped into firing twice.
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
        const SnackBar(content: Text('Photos approved')),
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

  void _openGallery(Property property, {required bool busy}) {
    final photos = property.imageUrls.isNotEmpty
        ? property.imageUrls
        : (property.imageUrl != null ? [property.imageUrl!] : <String>[]);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _GalleryReviewSheet(
        property: property,
        photos: photos,
        busy: busy,
        onApprove: () async {
          await _approve(property);
          if (context.mounted) Navigator.pop(ctx);
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
        title: const Text('Pending Verifications', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                      ElevatedButton(onPressed: _loadPending, child: const Text('Retry')),
                    ],
                  ),
                )
              : _pending.isEmpty
                  ? Center(
                      child: Text('No listings awaiting photo review.', style: TextStyle(color: Colors.grey[500])),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadPending,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _pending.length,
                        itemBuilder: (context, index) {
                          final property = _pending[index];
                          final busy = property.id != null && _busyIds.contains(property.id);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: busy ? null : () => _openGallery(property, busy: busy),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: property.imageUrl != null
                                        ? Image.network(property.imageUrl!, width: 60, height: 60, fit: BoxFit.cover)
                                        : Container(width: 60, height: 60, color: Colors.grey[800]),
                                  ),
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
                                      const SizedBox(height: 2),
                                      Text(
                                        '${property.imageUrls.length} photo${property.imageUrls.length == 1 ? '' : 's'} · ${property.landlordName ?? property.landlordPhone}',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                busy
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
                                      )
                                    : TextButton(
                                        onPressed: () => _openGallery(property, busy: busy),
                                        child: const Text('Review', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
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

class _GalleryReviewSheet extends StatelessWidget {
  final Property property;
  final List<String> photos;
  final bool busy;
  final VoidCallback onApprove;

  const _GalleryReviewSheet({
    required this.property,
    required this.photos,
    required this.busy,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                property.title,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${property.location} · Listed by ${property.landlordName ?? property.landlordPhone}',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: photos.isEmpty
                    ? Center(
                        child: Text('No photos on this listing.', style: TextStyle(color: Colors.grey[500])),
                      )
                    : GridView.builder(
                        controller: scrollController,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1,
                        ),
                        itemCount: photos.length,
                        itemBuilder: (context, index) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              photos[index],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: Colors.grey[850],
                                alignment: Alignment.center,
                                child: const Icon(Icons.broken_image_outlined, color: Colors.white38),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: busy ? null : onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Approve Photos', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
