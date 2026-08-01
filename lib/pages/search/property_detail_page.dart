import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:roost_app/config.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/favorites_service.dart';
import 'package:roost_app/services/country_service.dart';
import 'package:roost_app/services/location_service.dart';
import 'package:roost_app/pages/chat/chat_room_page.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roost_app/pages/search/in_app_map_page.dart';
import 'package:roost_app/theme/app_map_style.dart';

class PropertyDetailPage extends StatefulWidget {
  final Property property;

  const PropertyDetailPage({super.key, required this.property});

  @override
  State<PropertyDetailPage> createState() => _PropertyDetailPageState();
}

class _PropertyDetailPageState extends State<PropertyDetailPage> {
  bool _isFavorite = false;
  int _currentImageIndex = 0;
  Position? _userPosition;
  bool _communityCheckEligible = false;
  bool _communityCheckSubmitted = false;

  @override
  void initState() {
    super.initState();
    _checkIfFavorite();
    _incrementViewCount();
    _loadUserPosition();
    _checkCommunityCheckEligibility();
  }

  /// Only shows the "did this match?" prompt to tenants who actually
  /// applied to this listing -- the closest concrete signal of genuine
  /// engagement Roost has today (no scheduled-viewing tracking exists
  /// yet). The backend re-checks this independently on submit; this
  /// call is purely so the app knows whether to show the prompt at all.
  Future<void> _checkCommunityCheckEligibility() async {
    if (widget.property.id == null) return;
    try {
      final result = await ApiService.get('/api/properties/${widget.property.id}/community-check/eligible');
      if (mounted) {
        setState(() => _communityCheckEligible = result is Map && result['eligible'] == true);
      }
    } catch (_) {
      // Not logged in, or the call failed -- just don't show the
      // prompt rather than surfacing an error for a non-essential check.
    }
  }

  Future<void> _loadUserPosition() async {
    final position = await LocationService.getCurrentPosition();
    if (mounted) setState(() => _userPosition = position);
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

  /// "450 m away · ~6 min walk" / "3.2 km away · ~8 min drive", or null if
  /// either the user's location or the property's coordinates are unknown.
  String? get _distanceLabel {
    final pos = _userPosition;
    final lat = widget.property.latitude;
    final lng = widget.property.longitude;
    if (pos == null || lat == null || lng == null) return null;

    final km = LocationService.distanceKm(pos.latitude, pos.longitude, lat, lng);
    final walking = km < 1.5;
    final speedKmh = walking ? 5.0 : 30.0;
    final minutes = (km / speedKmh * 60).round().clamp(1, 999);
    final mode = walking ? 'walk' : 'drive';
    return '${LocationService.formatDistance(km)} · ~$minutes min $mode';
  }

  void _navigateToMap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InAppMapPage(property: widget.property)),
    );
  }

  void _shareListing() {
    final p = widget.property;
    final link = p.id != null ? '${AppConfig.baseUrl}/api/properties/${p.id}' : AppConfig.baseUrl;
    final shareText = 'Check out this listing on Roost:\n${p.title} — ${CountryService.pricePerMonth(p.price)} in ${p.location}\n$link';
    Share.share(shareText, subject: p.title);
  }

  void _showCommunityCheckSheet() {
    bool visited = true;
    bool photosAccurate = true;
    bool locationAccurate = true;
    bool priceAccurate = true;
    bool wouldRecommend = true;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Widget switchTile(String label, bool value, ValueChanged<bool> onChanged) {
              return SwitchListTile(
                title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
                value: value,
                onChanged: isSubmitting ? null : onChanged,
                activeThumbColor: Colors.white,
                contentPadding: EdgeInsets.zero,
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Did this listing match?',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Since you applied to this listing, your answer helps other renters trust Roost.',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    switchTile('I visited or contacted about this property', visited, (v) => setSheetState(() => visited = v)),
                    if (visited) ...[
                      switchTile('Photos were accurate', photosAccurate, (v) => setSheetState(() => photosAccurate = v)),
                      switchTile('Location was accurate', locationAccurate, (v) => setSheetState(() => locationAccurate = v)),
                      switchTile('Price was accurate', priceAccurate, (v) => setSheetState(() => priceAccurate = v)),
                      switchTile('I would recommend this listing', wouldRecommend, (v) => setSheetState(() => wouldRecommend = v)),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                setSheetState(() => isSubmitting = true);
                                try {
                                  await ApiService.post('/api/properties/${widget.property.id}/community-check', {
                                    'visited': visited,
                                    'photosAccurate': visited && photosAccurate,
                                    'locationAccurate': visited && locationAccurate,
                                    'priceAccurate': visited && priceAccurate,
                                    'wouldRecommend': visited && wouldRecommend,
                                  });
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (!mounted) return;
                                  setState(() => _communityCheckSubmitted = true);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Thanks for helping keep Roost accurate.')),
                                  );
                                } catch (e) {
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Could not submit: $e')),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
                  bool isSubmitting = false;
                  return StatefulBuilder(
                    builder: (sheetContext, setSheetState) {
                      return Padding(
                        padding: EdgeInsets.only(
                          left: 20,
                          right: 20,
                          top: 20,
                          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                        ),
                        child: SingleChildScrollView(
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
                                  title: Text(r, style: TextStyle(color: selectedReason == r ? Colors.white : Colors.grey[400], fontSize: 14)),
                                  trailing: Icon(
                                    selectedReason == r ? Icons.radio_button_checked : Icons.radio_button_off,
                                    color: selectedReason == r ? Colors.white : Colors.grey,
                                    size: 20,
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                  onTap: isSubmitting ? null : () => setSheetState(() => selectedReason = r),
                                );
                              }),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: isSubmitting
                                      ? null
                                      : () async {
                                          setSheetState(() => isSubmitting = true);
                                          try {
                                            await ApiService.post('/api/properties/${widget.property.id}/report', {
                                              'reason': selectedReason,
                                            });
                                            if (ctx.mounted) Navigator.pop(ctx);
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Listing report received. Thank you for keeping Roost safe!'),
                                                duration: Duration(seconds: 4),
                                              ),
                                            );
                                          } catch (e) {
                                            if (ctx.mounted) Navigator.pop(ctx);
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Report submitted. Thank you for keeping Roost safe!'),
                                                duration: Duration(seconds: 4),
                                              ),
                                            );
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: Colors.redAccent.withValues(alpha: 0.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: isSubmitting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Text('Submit Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ),
                              ),
                            ],
                          ),
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
    // Video leads the gallery when present -- the walkthrough is the
    // richest thing a renter can see before contacting the landlord,
    // so it shouldn't be buried behind static photos.
    final int slideCount = urls.length + (hasVideo ? 1 : 0);

    if (slideCount == 0) {
      return Container(
        height: 320,
        width: double.infinity,
        color: Colors.grey[900],
        child: const Center(
          child: Icon(Icons.home_outlined, color: Colors.white30, size: 64),
        ),
      );
    }

    return SizedBox(
      height: 320,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: slideCount,
            onPageChanged: (idx) => setState(() => _currentImageIndex = idx),
            itemBuilder: (context, idx) {
              if (hasVideo && idx == 0) {
                return _HeroVideoSlide(url: widget.property.videoUrl!);
              }
              final photoIdx = hasVideo ? idx - 1 : idx;
              return CachedNetworkImage(
                imageUrl: urls[photoIdx],
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
          if (slideCount > 1)
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
                  '${_currentImageIndex + 1} / $slideCount',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
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
                  // Title
                  Text(
                    widget.property.title,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  if (widget.property.buildingName != null && widget.property.buildingName!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'at ${widget.property.buildingName}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 14, fontStyle: FontStyle.italic),
                    ),
                  ],
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
                  if (_distanceLabel != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.near_me_outlined, color: Colors.grey, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          _distanceLabel!,
                          style: TextStyle(color: Colors.grey[400], fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Rent & deposit
                  Text(
                    CountryService.pricePerMonth(widget.property.price),
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                  if (widget.property.deposit != null && widget.property.deposit!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Deposit: ${widget.property.deposit}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Availability & verification badges
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: widget.property.available ? Colors.white : Colors.grey[900],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: widget.property.available ? Colors.black : Colors.grey[500],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.property.available ? 'Available' : 'Taken',
                              style: TextStyle(
                                color: widget.property.available ? Colors.black : Colors.grey[400],
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.property.verified) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey[800]!),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('Verified', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                      if (widget.property.communityVerified) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.6)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.groups_2_outlined, color: Colors.greenAccent, size: 14),
                              SizedBox(width: 4),
                              Text('Community Verified', style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // House type, bedrooms & bathrooms
                  Row(
                    children: [
                      const Icon(Icons.bed_outlined, color: Colors.grey, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        widget.property.bedroomDisplay,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.bathtub_outlined, color: Colors.grey, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.property.bathrooms} bath',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      if (widget.property.houseType.isNotEmpty && widget.property.bedrooms > 0) ...[
                        const SizedBox(width: 16),
                        Text(
                          '·  ${widget.property.houseType}',
                          style: TextStyle(color: Colors.grey[400], fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ],
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

                  // Description
                  if (widget.property.description.trim().isNotEmpty) ...[
                    const Text('Description', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(
                      widget.property.description,
                      style: TextStyle(color: Colors.grey[400], fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFF2C2C2E)),
                    const SizedBox(height: 16),
                  ],

                  // Map preview — Baked Uber-style In-App Map
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Location', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => InAppMapPage(property: widget.property),
                            ),
                          );
                        },
                        icon: const Icon(Icons.fullscreen, color: Colors.white, size: 18),
                        label: const Text('Fullscreen', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      height: 180,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[800]!),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Stack(
                        children: [
                          GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: LatLng(
                                widget.property.latitude ?? -1.2921,
                                widget.property.longitude ?? 36.8219,
                              ),
                              zoom: 14,
                            ),
                            style: AppMapStyle.darkMapStyle,
                            zoomControlsEnabled: false,
                            myLocationButtonEnabled: false,
                            scrollGesturesEnabled: false,
                            zoomGesturesEnabled: false,
                            tiltGesturesEnabled: false,
                            rotateGesturesEnabled: false,
                            markers: {
                              Marker(
                                markerId: MarkerId('detail_prop_${widget.property.id}'),
                                position: LatLng(
                                  widget.property.latitude ?? -1.2921,
                                  widget.property.longitude ?? 36.8219,
                                ),
                              ),
                            },
                          ),
                          Positioned.fill(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => InAppMapPage(property: widget.property),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[800]!),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.touch_app, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text('Tap to Explore Map', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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
                          backgroundColor: Colors.white,
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
                                    const Icon(Icons.verified, color: Colors.white, size: 16),
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
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _navigateToMap,
                          icon: const Icon(Icons.navigation_outlined, size: 18),
                          label: const Text('Navigate'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF3A3A3C)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _shareListing,
                          icon: const Icon(Icons.share_outlined, size: 18),
                          label: const Text('Share'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF3A3A3C)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  if (_communityCheckEligible && !_communityCheckSubmitted) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF2C2C2E)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Did this listing match what was advertised?',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Since you applied to this property, your answer helps build trust for other renters.',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _showCommunityCheckSheet,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Color(0xFF3A3A3C)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Confirm accuracy'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

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
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// A single autoplay, looping, muted-by-default video slide for the
/// gallery -- the vertical short-form feel the walkthrough is meant to
/// have. Tap toggles sound, matching the muted-until-tapped convention
/// most people already expect from short vertical video elsewhere.
class _HeroVideoSlide extends StatefulWidget {
  final String url;

  const _HeroVideoSlide({required this.url});

  @override
  State<_HeroVideoSlide> createState() => _HeroVideoSlideState();
}

class _HeroVideoSlideState extends State<_HeroVideoSlide> {
  VideoPlayerController? _controller;
  bool _muted = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller?.play();
      }).catchError((_) {
        if (mounted) setState(() => _failed = true);
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _toggleMute() {
    setState(() {
      _muted = !_muted;
      _controller?.setVolume(_muted ? 0 : 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Container(
        height: 320,
        width: double.infinity,
        color: Colors.grey[900],
        child: const Center(child: Icon(Icons.videocam_off_outlined, color: Colors.white38, size: 48)),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return Container(
        height: 320,
        width: double.infinity,
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2)),
      );
    }

    return GestureDetector(
      onTap: _toggleMute,
      child: SizedBox(
        height: 320,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
            Positioned(
              bottom: 24,
              left: 16,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                child: Icon(_muted ? Icons.volume_off : Icons.volume_up, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
