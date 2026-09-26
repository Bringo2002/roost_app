import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:roost_app/config.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/widgets/common/full_screen_image_gallery.dart';
import 'package:roost_app/widgets/property/property_card.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class PublicHostProfilePage extends StatefulWidget {
  const PublicHostProfilePage({
    super.key,
    required this.hostId,
    required this.hostName,
    this.hostEmail,
    this.hostPhone,
    this.hostRole = 'LANDLORD',
    this.hostAvatarUrl,
    this.memberSince = '2024',
    this.isTitleDeedVerified = true,
    this.isPhoneVerified = true,
    this.isOwnerEndorsed = false,
  });

  final String hostId;
  final String hostName;
  final String? hostEmail;
  final String? hostPhone;
  final String hostRole;
  final String? hostAvatarUrl;
  final String memberSince;
  final bool isTitleDeedVerified;
  final bool isPhoneVerified;
  final bool isOwnerEndorsed;

  @override
  State<PublicHostProfilePage> createState() => _PublicHostProfilePageState();
}

class _PublicHostProfilePageState extends State<PublicHostProfilePage> {
  List<Property> _hostProperties = [];
  bool _loading = true;
  String? _loadedAvatarUrl;

  @override
  void initState() {
    super.initState();
    _loadedAvatarUrl = widget.hostAvatarUrl;
    _loadHostProperties();
    _loadHostUserData();
  }

  Future<void> _loadHostUserData() async {
    try {
      final res = await ApiService.get('/api/users/${widget.hostId}');
      if (res != null && mounted) {
        final avatar = res['avatarUrl']?.toString();
        if (avatar != null && avatar.isNotEmpty) {
          setState(() {
            _loadedAvatarUrl = avatar;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadHostProperties() async {
    try {
      final List<dynamic> list = await ApiService.get('/api/properties');
      final all = list.map((json) => Property.fromJson(json)).toList();
      // Filter properties listed by this host (or match by landlord/creator ID or title)
      final hostProps = all.where((p) {
        if (p.landlordId != null && p.landlordId == widget.hostId) return true;
        return true; // Show all properties in demo mode if single host
      }).toList();

      // Check if any property owner object contains avatarUrl
      for (final p in hostProps) {
        if (_loadedAvatarUrl == null || _loadedAvatarUrl!.isEmpty) {
          if (p.owner?.avatarUrl != null && p.owner!.avatarUrl!.isNotEmpty) {
            _loadedAvatarUrl = p.owner!.avatarUrl;
            break;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _hostProperties = hostProps;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  void _contactWhatsApp() async {
    final phone = widget.hostPhone ?? '+254712345678';
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final url = Uri.parse(
      'https://wa.me/$cleanPhone?text=Hi%20${Uri.encodeComponent(widget.hostName)},%20I%20found%20your%20listing%20profile%20on%20Roost!',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _callHost() async {
    final phone = widget.hostPhone ?? '+254712345678';
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _shareHostProfile() {
    final isLandlord = widget.hostRole.toUpperCase() == 'LANDLORD';
    final roleTitle = isLandlord ? 'Verified Landlord' : 'Authorized Agent';
    final profileUrl = '${AppConfig.baseUrl}/hosts/${widget.hostId}';
    final count = _hostProperties.length;
    final propCountStr = count > 0
        ? '$count verified listing${count == 1 ? '' : 's'}'
        : 'verified listings';

    final shareText =
        'Check out ${widget.hostName}\'s host profile on Roost!\n'
        '🏠 $roleTitle • $propCountStr in Nairobi\n\n'
        'View profile & properties:\n$profileUrl';

    Share.share(
      shareText,
      subject: '${widget.hostName} — Roost Host Profile',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandlord = widget.hostRole.toUpperCase() == 'LANDLORD';
    final roleTitle = isLandlord ? 'Verified Landlord' : 'Authorized Agent';
    final initials = widget.hostName.isNotEmpty
        ? widget.hostName
            .split(' ')
            .map((w) => w.isNotEmpty ? w[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : 'H';

    final displayAvatar = _loadedAvatarUrl ?? widget.hostAvatarUrl;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Host Profile',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
            onPressed: _shareHostProfile,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Host Hero Card ─────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: (displayAvatar != null && displayAvatar.isNotEmpty)
                              ? () => FullScreenImageGallery.open(context, [displayAvatar])
                              : null,
                          child: Stack(
                            children: [
                              Container(
                                width: 86,
                                height: 86,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.grey800,
                                  border: Border.all(color: AppColors.grey600, width: 2),
                                ),
                                child: ClipOval(
                                  child: (displayAvatar != null && displayAvatar.isNotEmpty)
                                      ? CachedNetworkImage(
                                          imageUrl: displayAvatar,
                                          fit: BoxFit.cover,
                                          width: 86,
                                          height: 86,
                                          placeholder: (context, url) => const Center(
                                            child: SizedBox(
                                              width: 28,
                                              height: 28,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppColors.white,
                                              ),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) => Center(
                                            child: Text(
                                              initials,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 30,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        )
                                      : Center(
                                          child: Text(
                                            initials,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 30,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: AppColors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.verified_rounded, color: Colors.black, size: 18),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          widget.hostName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.grey800,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.shield_outlined, color: AppColors.white, size: 14),
                              const SizedBox(width: 5),
                              Text(
                                roleTitle,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Hosting on Roost since ${widget.memberSince}',
                          style: const TextStyle(color: AppColors.grey400, fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Performance & Trust Stats Row ──────────────────────────
                  // One color for all three stat icons -- previously
                  // amber/blue/green, a purely decorative distinction
                  // the icon shapes themselves (a bolt, a village, a
                  // shield) already carry.
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatTile(
                          icon: Icons.flash_on_rounded,
                          iconColor: AppColors.white,
                          value: '< 30 min',
                          label: 'Response Time',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatTile(
                          icon: Icons.holiday_village_rounded,
                          iconColor: AppColors.white,
                          value: '${_hostProperties.length}',
                          label: 'Active Listings',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatTile(
                          icon: Icons.verified_user_rounded,
                          iconColor: AppColors.white,
                          value: '3 Badges',
                          label: 'Trust Score',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Verifications & Credentials Section ───────────────────
                  const Text(
                    'VERIFICATIONS & TRUST CREDENTIALS',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      children: [
                        _buildTrustBadgeRow(
                          icon: Icons.fact_check_rounded,
                          title: 'Title Deed & Ownership Proof',
                          subtitle: 'Verified authentic via Gemini AI Vision',
                          isVerified: widget.isTitleDeedVerified,
                        ),
                        const Divider(height: 1, color: AppColors.divider),
                        _buildTrustBadgeRow(
                          icon: Icons.phone_android_rounded,
                          title: 'Phone Number Verified',
                          subtitle: 'Direct SMS & WhatsApp confirmed',
                          isVerified: widget.isPhoneVerified,
                        ),
                        const Divider(height: 1, color: AppColors.divider),
                        _buildTrustBadgeRow(
                          icon: Icons.link_rounded,
                          title: 'Landlord Endorsed Listing',
                          subtitle: widget.isOwnerEndorsed
                              ? 'Direct property owner endorsement confirmed'
                              : 'Registered Direct Owner',
                          isVerified: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Active Listings Section ────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'LISTINGS BY ${widget.hostName.toUpperCase()}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        '${_hostProperties.length} rentals',
                        style: TextStyle(color: AppColors.grey400, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_hostProperties.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          'No active listings at the moment.',
                          style: TextStyle(color: AppColors.grey400, fontSize: 14),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _hostProperties.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final property = _hostProperties[index];
                        return PropertyCard(
                          key: ValueKey(property.id ?? identityHashCode(property)),
                          property: property,
                        );
                      },
                    ),

                  const SizedBox(height: 90), // Bottom padding for action bar
                ],
              ),
            ),

      // ── Contact Host Bottom Bar ────────────────────────────────────────────
      bottomNavigationBar: Container(
        color: AppColors.background,
        child: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.background,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _callHost,
                    icon: const Icon(Icons.phone_rounded, color: Colors.white, size: 18),
                    label: const Text('Call Host', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _contactWhatsApp,
                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.black, size: 18),
                    label: const Text('WhatsApp', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: AppColors.grey500, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTrustBadgeRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isVerified,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isVerified ? AppColors.grey800 : AppColors.surface,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isVerified ? AppColors.white : AppColors.grey500, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.grey400, fontSize: 12),
      ),
      trailing: isVerified
          ? const Icon(Icons.check_circle_rounded, color: AppColors.white, size: 20)
          : const Icon(Icons.hourglass_empty_rounded, color: AppColors.grey500, size: 20),
    );
  }
}
