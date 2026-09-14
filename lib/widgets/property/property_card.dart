import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/pages/chat/chat_room_page.dart';
import 'package:roost_app/pages/search/property_detail_page.dart';
import 'package:roost_app/pages/search/in_app_map_page.dart';
import 'package:roost_app/theme/app_colors.dart';
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
    this.onCall,
    this.onChat,
    this.onNavigate,
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

  /// Overrides the card's default call/chat/navigate behavior. Each
  /// defaults to null, in which case the card falls back to its own
  /// built-in behavior (dial the primary contact, open the in-app chat,
  /// push the map page) -- so every existing call site keeps working
  /// unchanged. Callers that need different behavior (e.g. a landlord
  /// previewing their own listing, where "call" makes no sense) can
  /// override just the actions that need to differ.
  final VoidCallback? onCall;
  final VoidCallback? onChat;
  final VoidCallback? onNavigate;

  @override
  State<PropertyCard> createState() => _PropertyCardState();
}

class _PropertyCardState extends State<PropertyCard> {
  Property get property => widget.property;
  bool _pressed = false;

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

  void _handleFavoriteTap() {
    if (widget.onFavoriteTap == null) return;
    HapticFeedback.lightImpact();
    widget.onFavoriteTap!();
  }

  void _handleCall() => (widget.onCall ?? _callLandlord)();

  void _callLandlord() async {
    final phone = property.primaryViewingPhone.replaceAll(' ', '');
    if (phone.isNotEmpty) {
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  void _handleChat(BuildContext context) => widget.onChat != null ? widget.onChat!() : _chatLandlord(context);

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

  void _handleNavigate() => (widget.onNavigate ?? _navigateToMap)();

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
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        if (widget.onTap != null) {
          widget.onTap!();
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PropertyDetailPage(property: property)),
          );
        }
      },
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
        margin: widget.margin,
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x28000000),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image section (180px height)
            if (widget.showTopImage)
              Stack(
                children: [
                  PropertyImage(
                    imageUrls: _galleryUrls,
                    height: widget.compact ? 140 : 180,
                    heroTag: widget.heroTag,
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: _handleFavoriteTap,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey(widget.isFavorite),
                          tween: Tween(begin: 0.6, end: 1.0),
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.elasticOut,
                          builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                          child: Icon(
                            widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: widget.isFavorite ? Colors.redAccent : AppColors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (property.verified)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, color: AppColors.black, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Verified',
                              style: TextStyle(
                                color: AppColors.black,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
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
                  // Title & availability indicator
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          property.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (!property.available) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.grey700,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Taken',
                          style: TextStyle(
                            color: AppColors.grey500,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Location
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: AppColors.grey500, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          property.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.grey400, fontSize: 13),
                        ),
                      ),
                      if (widget.distanceLabel != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '· ${widget.distanceLabel}',
                          style: const TextStyle(color: AppColors.grey500, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Price & Rental badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formattedPrice,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.grey900,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.grey800),
                        ),
                        child: Text(
                          property.type.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Management role badge (only for non-direct-owner listings).
                  // Endorsed roles get the solid-white treatment (same
                  // solid-vs-outline hierarchy as everywhere else); plain
                  // caretaker/agent roles get the subdued grey fill. No
                  // accent color -- this previously used a purple tint
                  // that didn't match the monochrome badge on the detail
                  // page for the same property.
                  if (!property.isDirectLandlord) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: property.landlordEndorsed ? AppColors.white : AppColors.grey800,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        property.managementBadgeLabel,
                        style: TextStyle(
                          color: property.landlordEndorsed ? AppColors.black : AppColors.grey400,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Bedroom & bathroom details
                  Row(
                    children: [
                      const Icon(Icons.bed_outlined, color: AppColors.grey500, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        property.bedroomDisplay,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.bathtub_outlined, color: AppColors.grey500, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${property.bathrooms} bath',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      if (property.houseType.isNotEmpty && property.bedrooms > 0) ...[
                        const SizedBox(width: 12),
                        Text(
                          '·  ${property.houseType}',
                          style: const TextStyle(color: AppColors.grey400, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 14),

                  const Divider(height: 1, color: AppColors.divider),

                  const SizedBox(height: 10),

                  // Action buttons: Call | Chat | Navigate
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _handleCall,
                          icon: const Icon(Icons.phone_outlined, size: 16),
                          label: const Text('Call'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.white,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _handleChat(context),
                          icon: const Icon(Icons.chat_bubble_outline, size: 16),
                          label: const Text('Chat'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.white,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _handleNavigate,
                          icon: const Icon(Icons.navigation_outlined, size: 16),
                          label: const Text('Navigate'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.white,
                            foregroundColor: AppColors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      ),
    );
  }
}
