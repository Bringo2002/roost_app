import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/pages/chat/chat_room_page.dart';
import 'package:roost_app/pages/search/property_detail_page.dart';
import 'package:roost_app/pages/search/in_app_map_page.dart';
import 'package:roost_app/widgets/property/property_image.dart';
import 'package:roost_app/services/country_service.dart';

class PropertyCard extends StatefulWidget {
  const PropertyCard({
    super.key,
    required this.property,
    this.onTap,
    this.onFavoriteTap,
    this.isFavorite = false,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.showTopImage = true,
    this.compact = false,
    this.heroTag,
    this.distanceLabel,
  });

  final Property property;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;
  final bool isFavorite;
  final EdgeInsets margin;
  final bool showTopImage;
  final bool compact;
  final Object? heroTag;

  /// Optional "450 m away" style label shown next to the location row.
  /// Left null by callers that don't have a resolved user position yet.
  final String? distanceLabel;

  @override
  State<PropertyCard> createState() => _PropertyCardState();
}

class _PropertyCardState extends State<PropertyCard> {
  Property get property => widget.property;

  List<String> get _galleryUrls {
    final urls = <String>[];
    if (property.imageUrl != null && property.imageUrl!.trim().isNotEmpty) {
      urls.add(property.imageUrl!);
    }
    for (final url in property.imageUrls) {
      if (url.trim().isNotEmpty && !urls.contains(url)) {
        urls.add(url);
      }
    }
    return urls;
  }

  void _callLandlord() async {
    final phone = property.landlordPhone.replaceAll(' ', '');
    if (phone.isNotEmpty) {
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  void _chatLandlord(BuildContext context) {
    if (property.owner != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomPage(partner: property.owner!),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Landlord contact unavailable for chat')),
      );
    }
  }

  void _navigateToMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InAppMapPage(property: widget.property),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedPrice = CountryService.pricePerMonth(property.price);

    return GestureDetector(
      onTap: widget.onTap ?? () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PropertyDetailPage(property: property)),
        );
      },
      child: Container(
        margin: widget.margin,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image section with Vignettes & Overlay Badges
            if (widget.showTopImage)
              Stack(
                children: [
                  PropertyImage(
                    imageUrls: _galleryUrls,
                    height: widget.compact ? 140 : 185,
                    heroTag: widget.heroTag,
                  ),

                  // Top Vignette Gradient Overlay
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.5),
                            Colors.transparent,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),

                  // Favorite Heart Action Button
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: widget.onFavoriteTap,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: Icon(
                            widget.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: widget.isFavorite ? Colors.redAccent : Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Verified Landlord Pill Badge
                  if (property.verified)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xDD000000),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.verified_rounded, color: Colors.greenAccent, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'VERIFIED LANDLORD',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Availability Indicator
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          property.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: property.available
                              ? Colors.greenAccent.withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: property.available
                                ? Colors.greenAccent.withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: property.available ? Colors.greenAccent : Colors.grey[500],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              property.available ? 'Available' : 'Booked',
                              style: TextStyle(
                                color: property.available ? Colors.greenAccent : Colors.grey[400],
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Location & Distance Pin
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 14),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          property.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey[400], fontSize: 13),
                        ),
                      ),
                      if (widget.distanceLabel != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.distanceLabel!,
                            style: TextStyle(color: Colors.grey[300], fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Rent Price & House Type Pill
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formattedPrice,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Text(
                          property.houseType.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Frosted Amenity Micro-Chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildFAANGSpecChip(property.bedroomDisplay, Icons.bed_rounded),
                      _buildFAANGSpecChip('${property.bathrooms} Bath', Icons.shower_rounded),
                      if (property.wifi) _buildFAANGSpecChip('WiFi', Icons.wifi_rounded),
                      if (property.furnished) _buildFAANGSpecChip('Furnished', Icons.chair_rounded),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                  const SizedBox(height: 12),

                  // FAANG Balanced Action Row: Quick Icons (Call, Chat) + Prominent Primary CTA (Navigate)
                  Row(
                    children: [
                      // Call Icon Button
                      InkWell(
                        onTap: _callLandlord,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: const Icon(Icons.phone_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Chat Icon Button
                      InkWell(
                        onTap: () => _chatLandlord(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Primary Filled Navigate Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _navigateToMap,
                          icon: const Icon(Icons.near_me_rounded, size: 16),
                          label: const Text(
                            'Navigate Map',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAANGSpecChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.grey[400], size: 11),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: Colors.grey[300], fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
