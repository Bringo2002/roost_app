import 'package:flutter/material.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/auth_service.dart';
import 'package:roost_app/pages/auth/welcome_page.dart';
import 'package:roost_app/pages/landlord/landlord_dashboard_page.dart';
import 'package:roost_app/pages/landlord/landlord_verification_hub_page.dart';
import 'package:roost_app/pages/landlord/endorsement_page.dart';
import 'package:roost_app/pages/admin/admin_flagged_listings_page.dart';
import 'package:roost_app/pages/admin/admin_pending_verifications_page.dart';
import 'package:roost_app/pages/profile/saved_page.dart';
import 'package:roost_app/pages/profile/public_host_profile_page.dart';

import 'package:roost_app/models/country_config.dart';
import 'package:roost_app/services/country_service.dart';
import 'package:roost_app/services/push_notification_service.dart';
import 'package:roost_app/pages/profile/notifications_page.dart';
import 'package:roost_app/pages/profile/privacy_policy_page.dart';
import 'package:roost_app/pages/profile/about_page.dart';
import 'package:roost_app/pages/profile/change_password_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  String? _error;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final notifEnabled = await PushNotificationService.isEnabled();
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _notificationsEnabled = notifEnabled;
    });
    try {
      final data = await ApiService.get('/api/users/me');
      if (!mounted) return;
      setState(() {
        _user = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _logout() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomePage()),
        (route) => false,
      );
    }
  }

  Future<void> _becomeLandlord() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiService.post('/api/auth/lister-profile');
      await _loadProfile();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Host mode enabled! Welcome to hosting on Roost.')),
      );
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LandlordDashboardPage()));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not enable hosting: $e')),
      );
    }
  }

  void _openPublicProfile() {
    final name = _user?['name'] ?? 'Landlord Host';
    final email = _user?['email'] ?? '';
    final phone = _user?['phone'] ?? '+254 712 345 678';
    final role = _user?['role'] ?? 'LANDLORD';
    final id = _user?['_id'] ?? _user?['id'] ?? 'user_123';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicHostProfilePage(
          hostId: id.toString(),
          hostName: name.toString(),
          hostEmail: email.toString(),
          hostPhone: phone.toString(),
          hostRole: role.toString(),
          isTitleDeedVerified: true,
          isPhoneVerified: true,
          isOwnerEndorsed: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Failed to load profile', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadProfile,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final name = _user?['name'] ?? 'User';
    final email = _user?['email'] ?? '';
    final phone = _user?['phone'] ?? '+254 712 345 678';
    final role = _user?['role'] ?? 'TENANT';
    final isLandlord = role.toString().toUpperCase() == 'LANDLORD';
    final isAdmin = role.toString().toUpperCase() == 'ADMIN';
    final initials = name.isNotEmpty
        ? name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : 'R';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: PushNotificationService.unreadCountNotifier,
            builder: (context, unreadCount, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 24),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage()));
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Hero Banner ("Become a Host" / "Verified Host Status") ──
                _buildHeroCard(isLandlord),

                const SizedBox(height: 20),

                // ── User Header Card ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF2C2C2E)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF2C2C2E),
                          border: Border.all(color: const Color(0xFF38BDF8), width: 2),
                        ),
                        child: Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              phone,
                              style: TextStyle(color: Colors.grey[400], fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              email,
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Group 1: Account & Public Profile ───────────────────────
                const Text(
                  'ACCOUNT SETTINGS',
                  style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF2C2C2E)),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person_outline_rounded, color: Colors.white),
                        title: const Text('View Public Profile', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          isLandlord ? 'Preview how tenants view your trust badges & listings' : 'Preview your user profile',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: _openPublicProfile,
                      ),
                      const Divider(height: 1, color: Color(0xFF2C2C2E)),
                      ListTile(
                        leading: const Icon(Icons.favorite_border_rounded, color: Colors.white),
                        title: const Text('Saved Properties', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedPage()));
                        },
                      ),
                      const Divider(height: 1, color: Color(0xFF2C2C2E)),
                      ListTile(
                        leading: const Icon(Icons.lock_outline_rounded, color: Colors.white),
                        title: const Text('Change Password', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordPage()));
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Group 2: Hosting & Verification ──────────────────────────
                const Text(
                  'HOSTING & VERIFICATION',
                  style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF2C2C2E)),
                  ),
                  child: Column(
                    children: [
                      if (isLandlord) ...[
                        ListTile(
                          leading: const Icon(Icons.shield_outlined, color: Color(0xFF38BDF8)),
                          title: const Text('Landlord Verification Center', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                          subtitle: const Text('Upload title deeds & AI verification', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const LandlordVerificationHubPage()));
                          },
                        ),
                        const Divider(height: 1, color: Color(0xFF2C2C2E)),
                        ListTile(
                          leading: const Icon(Icons.holiday_village_outlined, color: Colors.white),
                          title: const Text('My Listed Properties', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const LandlordDashboardPage()));
                          },
                        ),
                        const Divider(height: 1, color: Color(0xFF2C2C2E)),
                        ListTile(
                          leading: const Icon(Icons.link_rounded, color: Colors.white),
                          title: const Text('Endorse a Caretaker / Agent', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const EndorsementPage()));
                          },
                        ),
                      ] else ...[
                        ListTile(
                          leading: const Icon(Icons.add_home_work_outlined, color: Color(0xFF38BDF8)),
                          title: const Text('Become a Host / List Property', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                          subtitle: const Text('Enable hosting mode to list properties on Roost', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                          onTap: _becomeLandlord,
                        ),
                      ],

                      if (isAdmin) ...[
                        const Divider(height: 1, color: Color(0xFF2C2C2E)),
                        ListTile(
                          leading: const Icon(Icons.verified_outlined, color: Colors.amber),
                          title: const Text('Pending Admin Verifications', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPendingVerificationsPage()));
                          },
                        ),
                        const Divider(height: 1, color: Color(0xFF2C2C2E)),
                        ListTile(
                          leading: const Icon(Icons.flag_outlined, color: Colors.redAccent),
                          title: const Text('Flagged Listings Audit', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFlaggedListingsPage()));
                          },
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Group 3: Preferences & System Settings ───────────────────
                const Text(
                  'PREFERENCES & REGION',
                  style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF2C2C2E)),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.notifications_outlined, color: Colors.white),
                        title: const Text('Push Notifications', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                        value: _notificationsEnabled,
                        activeThumbColor: Colors.white,
                        onChanged: (val) async {
                          final messenger = ScaffoldMessenger.of(context);
                          setState(() => _notificationsEnabled = val);
                          await PushNotificationService.setEnabled(val);
                          messenger.hideCurrentSnackBar();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(val ? 'Push notifications enabled' : 'Push notifications disabled'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1, color: Color(0xFF2C2C2E)),
                      ListTile(
                        leading: const Icon(Icons.language_outlined, color: Colors.white),
                        title: const Text('Country / Region', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${CountryService.config.flag} ${CountryService.config.code}',
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                        onTap: () => _showCountryPickerBottomSheet(context),
                      ),
                      const Divider(height: 1, color: Color(0xFF2C2C2E)),
                      ListTile(
                        leading: const Icon(Icons.location_on_outlined, color: Colors.white),
                        title: const Text('Location Access', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                        trailing: Text('Enabled', style: TextStyle(color: Colors.grey[400], fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Group 4: Support & Legal ─────────────────────────────────
                const Text(
                  'SUPPORT & LEGAL',
                  style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF2C2C2E)),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined, color: Colors.white),
                        title: const Text('Privacy Policy', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()));
                        },
                      ),
                      const Divider(height: 1, color: Color(0xFF2C2C2E)),
                      ListTile(
                        leading: const Icon(Icons.info_outline, color: Colors.white),
                        title: const Text('About Roost', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                        subtitle: Text('v1.0.2 · ${CountryService.config.name}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutRoostPage()));
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Sign Out Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: TextButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                    label: const Text(
                      'Log Out',
                      style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(height: 110), // Padding for floating switcher pill
              ],
            ),
          ),

          // ── Airbnb-Style Floating Mode Switcher Pill (`⇄ Switch to Hosting`) ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  if (isLandlord) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LandlordDashboardPage()));
                  } else {
                    _becomeLandlord();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 16,
                        spreadRadius: 2,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.swap_horiz_rounded, color: Colors.black, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        isLandlord ? 'Switch to Hosting Dashboard' : 'Switch to Hosting',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(bool isLandlord) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLandlord
              ? [const Color(0xFF0F2027), const Color(0xFF203A43), const Color(0xFF2C5364)]
              : [const Color(0xFF1F1C2C), const Color(0xFF928DAB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: (isLandlord ? const Color(0xFF38BDF8) : Colors.purpleAccent).withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isLandlord ? Icons.home_work_rounded : Icons.add_home_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLandlord ? 'Host Mode Active ✓' : 'Become a Host',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLandlord
                          ? 'Manage your properties, tenant inquiries & AI verifications.'
                          : "It's easy to start listing rentals and connect with verified tenants.",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              if (isLandlord) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LandlordDashboardPage()));
              } else {
                _becomeLandlord();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              isLandlord ? 'Go to Host Dashboard' : 'List Property',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _showCountryPickerBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Country / Region',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...CountryConfig.all.map((c) {
                  final isSelected = CountryService.config.code == c.code;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    leading: Text(c.flag, style: const TextStyle(fontSize: 28)),
                    title: Text(c.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text('${c.currencyCode} (${c.currencySymbol})', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.white) : null,
                    onTap: () async {
                      await CountryService.instance.setCountry(c);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (!mounted) return;
                      setState(() {});
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
