import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:roost_app/config.dart';
import 'package:roost_app/controllers/property_detail_controller.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/pages/chat/chat_room_page.dart';
import 'package:roost_app/pages/search/in_app_map_page.dart';
import 'package:roost_app/services/country_service.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/theme/app_map_style.dart';
import 'package:roost_app/widgets/property_detail/amenities_section.dart';
import 'package:roost_app/widgets/property_detail/community_check_sheet.dart';
import 'package:roost_app/widgets/property_detail/dual_contact_card.dart';
import 'package:roost_app/widgets/property_detail/free_viewings_banner.dart';
import 'package:roost_app/widgets/property_detail/glass_icon_button.dart';
import 'package:roost_app/widgets/property_detail/hero_media_gallery.dart';
import 'package:roost_app/widgets/property_detail/listing_caution_card.dart';
import 'package:roost_app/widgets/property_detail/property_bottom_bar.dart';
import 'package:roost_app/widgets/property_detail/quick_stats_row.dart';
import 'package:roost_app/widgets/property_detail/report_sheet.dart';
import 'package:roost_app/widgets/property_detail/section_header.dart';
import 'package:roost_app/widgets/property_detail/trust_verification_card.dart';
import 'package:roost_app/widgets/property_detail/verification_badges.dart';

class PropertyDetailPage extends StatefulWidget {
  const PropertyDetailPage({super.key, required this.property});

  final Property property;

  @override
  State<PropertyDetailPage> createState() => _PropertyDetailPageState();
}

class _PropertyDetailPageState extends State<PropertyDetailPage> with SingleTickerProviderStateMixin {
  late final PropertyDetailController _controller;
  late final AnimationController _entranceController;
  late final Animation<double> _entranceFade;
  late final Animation<Offset> _entranceSlide;

  Property get _property => widget.property;

  @override
  void initState() {
    super.initState();
    _controller = PropertyDetailController(property: widget.property)..init();
    _entranceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _entranceFade = CurvedAnimation(parent: _entranceController, curve: Curves.easeOut);
    _entranceSlide = Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeOut));
    _entranceController.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _callPrimaryContact() {
    final phone = _property.primaryViewingPhone;
    if (phone.isNotEmpty) launchUrl(Uri.parse('tel:$phone'));
  }

  void _openChat() {
    if (_property.owner != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatRoomPage(partner: _property.owner!)));
    }
  }

  void _navigateToMap() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => InAppMapPage(property: _property)));
  }

  void _shareListing() {
    final p = _property;
    final link = p.id != null ? '${AppConfig.baseUrl}/api/properties/${p.id}' : AppConfig.baseUrl;
    final shareText =
        'Check out this listing on Roost:\n${p.title} — ${CountryService.pricePerMonth(p.price)} in ${p.location}\n$link';
    Share.share(shareText, subject: p.title);
  }

  void _showVerificationDetails() => TrustVerificationCard.showDetails(context, _property);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => PropertyBottomBar(
          property: _property,
          onCall: _callPrimaryContact,
          onChat: _openChat,
        ),
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverAppBar(
                expandedHeight: kHeroMediaHeight,
                pinned: true,
                stretch: true,
                backgroundColor: AppColors.background,
                elevation: 0,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GlassIconButton(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
                ),
                actions: [
                  if (_property.id != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GlassIconButton(
                        icon: Icons.favorite_border,
                        onTap: _controller.toggleFavorite,
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey(_controller.isFavorite),
                          tween: Tween(begin: 0.6, end: 1.0),
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.elasticOut,
                          builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                          child: Icon(
                            _controller.isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: _controller.isFavorite ? Colors.redAccent : AppColors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GlassIconButton(icon: Icons.share_outlined, onTap: _shareListing),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
                  background: _property.id != null
                      ? Hero(tag: 'property-image-${_property.id}', child: HeroMediaGallery(property: _property))
                      : HeroMediaGallery(property: _property),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _entranceFade,
                  child: SlideTransition(position: _entranceSlide, child: _buildBody()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    final p = _property;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.4)),
          if (p.buildingName != null && p.buildingName!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('at ${p.buildingName}', style: TextStyle(color: AppColors.grey400, fontSize: 15, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 8),

          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: AppColors.grey500, size: 16),
              const SizedBox(width: 4),
              Expanded(child: Text(p.location, style: TextStyle(color: AppColors.grey400, fontSize: 14))),
            ],
          ),
          if (_controller.distanceLabel != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.near_me_outlined, color: AppColors.grey300, size: 13),
                  const SizedBox(width: 6),
                  Text(_controller.distanceLabel!, style: const TextStyle(color: AppColors.grey300, fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          VerificationBadges(property: p, onTapVerification: _showVerificationDetails),

          if (p.riskFlags.isNotEmpty) ...[
            const SizedBox(height: 16),
            ListingCautionCard(riskFlags: p.riskFlags),
          ],

          const SizedBox(height: 24),
          QuickStatsRow(property: p),

          const SizedBox(height: 28),
          const SectionHeader('Amenities'),
          const SizedBox(height: 14),
          AmenitiesSection(property: p),

          if (p.description.trim().isNotEmpty) ...[
            const SizedBox(height: 28),
            const SectionHeader('About this home'),
            const SizedBox(height: 10),
            Text(p.description, style: TextStyle(color: AppColors.grey300, fontSize: 15, height: 1.6)),
          ],

          const SizedBox(height: 28),
          SectionHeader(
            'Location & Surroundings',
            trailing: TextButton.icon(
              onPressed: _navigateToMap,
              icon: const Icon(Icons.fullscreen, color: AppColors.white, size: 18),
              label: const Text('Fullscreen', style: TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 10),
          _buildMapPreview(p),

          if (p.nearbyFacilities.isNotEmpty) ...[
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final facility in p.nearbyFacilities)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(_nearbyFacilityIcon(facility.category), color: AppColors.grey400, size: 16),
                        const SizedBox(width: 8),
                        Text(facility.label, style: TextStyle(color: AppColors.grey300, fontSize: 13)),
                      ],
                    ),
                  ),
              ],
            ),
          ],

          const SizedBox(height: 28),
          const SectionHeader('Hosted by'),
          const SizedBox(height: 12),
          TrustVerificationCard(property: p),

          const SizedBox(height: 16),
          DualContactCard(property: p),

          const SizedBox(height: 16),
          const FreeViewingsBanner(),

          const SizedBox(height: 24),
          if (_controller.communityCheckEligible && !_controller.communityCheckSubmitted) ...[
            _buildCommunityCheckPrompt(),
            const SizedBox(height: 20),
          ],

          Center(
            child: TextButton.icon(
              onPressed: () => ReportSheet.show(context, _controller),
              icon: const Icon(Icons.flag_outlined, color: AppColors.grey500, size: 16),
              label: const Text('Report an issue with this listing', style: TextStyle(color: AppColors.grey500, fontSize: 13)),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildMapPreview(Property p) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 200,
        decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(20)),
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: LatLng(p.latitude ?? -1.2921, p.longitude ?? 36.8219), zoom: 14),
              style: AppMapStyle.darkMapStyle,
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              scrollGesturesEnabled: false,
              zoomGesturesEnabled: false,
              tiltGesturesEnabled: false,
              rotateGesturesEnabled: false,
              markers: {
                Marker(markerId: MarkerId('detail_prop_${p.id}'), position: LatLng(p.latitude ?? -1.2921, p.longitude ?? 36.8219)),
              },
            ),
            Positioned.fill(child: Material(color: Colors.transparent, child: InkWell(onTap: _navigateToMap))),
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app, color: AppColors.white, size: 14),
                    SizedBox(width: 6),
                    Text('Tap to Explore Map', style: TextStyle(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _nearbyFacilityIcon(String category) {
    switch (category) {
      case 'mall':
        return Icons.shopping_bag_outlined;
      case 'hospital':
        return Icons.local_hospital_outlined;
      case 'road':
        return Icons.add_road_outlined;
      default:
        return Icons.place_outlined;
    }
  }

  Widget _buildCommunityCheckPrompt() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Did this listing match what was advertised?', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text('Since you applied to this property, your answer helps build trust for other renters.', style: TextStyle(color: AppColors.grey400, fontSize: 12)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => CommunityCheckSheet.show(context, _controller),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.white,
                side: const BorderSide(color: AppColors.grey700),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Confirm accuracy'),
            ),
          ),
        ],
      ),
    );
  }
}
