import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:roost_app/services/favorites_service.dart';
import 'package:roost_app/pages/chat/chat_room_page.dart';

class PropertyDetailPage extends StatefulWidget {
  final Property property;

  const PropertyDetailPage({super.key, required this.property});

  @override
  State<PropertyDetailPage> createState() => _PropertyDetailPageState();
}

class _PropertyDetailPageState extends State<PropertyDetailPage> {
  bool _isFavorite = false;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkIfFavorite();
    _incrementViewCount();
  }

  Future<void> _incrementViewCount() async {
    if (widget.property.id != null) {
      try {
        await ApiService.get('/api/properties/${widget.property.id}/view');
      } catch (_) {}
    }
  }

  Future<void> _checkIfFavorite() async {
    if (widget.property.id != null) {
      final fav = await FavoritesService.isFavorite(widget.property.id!);
      if (mounted) setState(() => _isFavorite = fav);
    }
  }

  Future<void> _toggleFavorite() async {
    if (widget.property.id != null) {
      await FavoritesService.toggle(widget.property.id!);
      _checkIfFavorite();
    }
  }

  void _openGoogleMapsNavigation() async {
    final lat = widget.property.latitude ?? -1.2921;
    final lng = widget.property.longitude ?? 36.8219;
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showReportBottomSheet() {
    String selectedReason = 'Fake listing';
    final List<String> reasons = [
      'Fake listing',
      'Incorrect price / hidden fees',
      'Already taken / not available',
      'Fraud or scam attempt',
      'Inaccurate photos / location',
      'Other',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Report Listing',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Help us keep Roost safe and verified. Why are you reporting this property?',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ...reasons.map((r) {
                    return ListTile(
                      title: Text(r, style: TextStyle(color: selectedReason == r ? const Color(0xFF00C853) : Colors.white, fontSize: 14)),
                      leading: Icon(
                        selectedReason == r ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: selectedReason == r ? const Color(0xFF00C853) : Colors.grey,
                        size: 20,
                      ),
                      contentPadding: EdgeInsets.zero,
                      onTap: () => setSheetState(() => selectedReason = r),
                    );
                  }),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await ApiService.post('/api/properties/${widget.property.id}/report', {
                            'reason': selectedReason,
                          });
                          Navigator.pop(ctx);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Report submitted. Thank you!')),
                          );
                        } catch (_) {
                          Navigator.pop(ctx);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Submit Report', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeroMedia() {
    final List<String> urls = [];
    if (widget.property.imageUrl != null && widget.property.imageUrl!.isNotEmpty) {
      urls.add(widget.property.imageUrl!);
    }
    for (final url in widget.property.imageUrls) {
      if (url.isNotEmpty && !urls.contains(url)) {
        urls.add(url);
      }
    }

    final hasVideo = widget.property.videoUrl != null && widget.property.videoUrl!.isNotEmpty;

    return Stack(
      alignment: Alignment.center,
      children: [
        if (false && hasVideo)
          Container(
            height: 320,
            width: double.infinity,
            color: Colors.grey[900],
            child: const Center(child: Icon(Icons.videocam, color: Colors.white38, size: 48)),
          )
        else if (urls.isEmpty)
          Container(
            height: 320,
            width: double.infinity,
            color: Colors.grey[900],
            child: const Center(
              child: Icon(Icons.home_outlined, color: Colors.white30, size: 64),
            ),
          )
        else
          SizedBox(
            height: 320,
            child: Stack(
              children: [
                PageView.builder(
                  itemCount: urls.length,
                  onPageChanged: (idx) => setState(() => _currentImageIndex = idx),
                  itemBuilder: (context, idx) {
                    return CachedNetworkImage(
                      imageUrl: urls[idx],
                      height: 320,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.black),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[900],
                        child: const Icon(Icons.broken_image, color: Colors.grey, size: 48),
                      ),
                    );
                  },
                ),
                if (urls.length > 1)
                  Positioned(
                    bottom: 24,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_currentImageIndex + 1} / ${urls.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final landlordName = widget.property.landlordName ?? (widget.property.owner?.name ?? 'Landlord');
    final firstLetter = landlordName.isNotEmpty ? landlordName[0].toUpperCase() : 'L';

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            expandedHeight: 320,
            pinned: true,
            actions: [
              if (widget.property.id != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    decoration: const BoxDecoration(color: Color(0x40000000), shape: BoxShape.circle),
                    child: IconButton(
                      icon: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: _isFavorite ? Colors.red : Colors.white,
                      ),
                      onPressed: _toggleFavorite,
                    ),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(background: _buildHeroMedia()),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Price
                  Text(
                    widget.property.title,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.grey, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.property.location,
                          style: TextStyle(color: Colors.grey[400], fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'KES ${NumberFormat('#,##0').format(widget.property.price)}/mo',
                    style: const TextStyle(color: Color(0xFF00C853), fontSize: 26, fontWeight: FontWeight.w900),
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFF2C2C2E)),
                  const SizedBox(height: 16),

                  // Amenities Row Grid
                  const Text('Amenities', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (widget.property.parking) _buildAmenityChip(Icons.directions_car, 'Parking'),
                      if (widget.property.wifi) _buildAmenityChip(Icons.wifi, 'WiFi'),
                      if (widget.property.water) _buildAmenityChip(Icons.water_drop, '24hr Water'),
                      if (widget.property.security) _buildAmenityChip(Icons.security, 'Security'),
                      if (widget.property.balcony) _buildAmenityChip(Icons.balcony, 'Balcony'),
                      if (widget.property.petFriendly) _buildAmenityChip(Icons.pets, 'Pet Friendly'),
                      if (widget.property.furnished) _buildAmenityChip(Icons.single_bed, 'Furnished'),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFF2C2C2E)),
                  const SizedBox(height: 16),

                  // Map preview
                  const Text('Location', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _openGoogleMapsNavigation,
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[800]!),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.map_outlined, color: Colors.grey[700], size: 48),
                          Positioned(
                            bottom: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00C853),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.navigation, color: Colors.black, size: 14),
                                  SizedBox(width: 4),
                                  Text('Navigate with Google Maps', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFF2C2C2E)),
                  const SizedBox(height: 16),

                  // Landlord Section
                  const Text('Landlord', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFF00C853),
                          child: Text(firstLetter, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(landlordName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                  if (widget.property.verified) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified, color: Color(0xFF00C853), size: 16),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text('Usually responds within 2 hours', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final phone = widget.property.landlordPhone;
                            if (phone.isNotEmpty) launchUrl(Uri.parse('tel:$phone'));
                          },
                          icon: const Icon(Icons.phone),
                          label: const Text('Call Landlord'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (widget.property.owner != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => ChatRoomPage(partner: widget.property.owner!)),
                              );
                            }
                          },
                          icon: const Icon(Icons.chat),
                          label: const Text('Chat'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C853),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Report Button
                  Center(
                    child: TextButton.icon(
                      onPressed: _showReportBottomSheet,
                      icon: const Icon(Icons.flag_outlined, color: Colors.grey, size: 16),
                      label: const Text('Report an issue with this listing', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmenityChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[900]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF00C853), size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
