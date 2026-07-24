import 'package:flutter/material.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/auth_service.dart';
import 'package:roost_app/pages/auth/welcome_page.dart';
import 'package:roost_app/pages/landlord/landlord_dashboard_page.dart';
import 'package:roost_app/pages/profile/saved_page.dart';

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
    final initials = name.isNotEmpty
        ? name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : 'R';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // Avatar Circle
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1C1C1E),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                name,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 4),

              Text(
                phone,
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 2),

              Text(
                email,
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),

              const SizedBox(height: 24),

              // Notifications & Saved & Listings Buttons
              ValueListenableBuilder<int>(
                valueListenable: PushNotificationService.unreadCountNotifier,
                builder: (context, unreadCount, child) {
                  return _buildMenuItemWithBadge(
                    Icons.notifications_outlined,
                    'Notification Center',
                    unreadCount,
                    () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage()));
                    },
                  );
                },
              ),

              _buildMenuItem(Icons.favorite_border, 'My Saved Properties', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedPage()));
              }),

              if (isLandlord)
                _buildMenuItem(Icons.holiday_village_outlined, 'My Listed Properties', () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LandlordDashboardPage()));
                }),

              const SizedBox(height: 24),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text('SETTINGS', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
              const SizedBox(height: 8),

              // Settings Items
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.notifications_outlined, color: Colors.white),
                      title: const Text('Push Notifications', style: TextStyle(color: Colors.white, fontSize: 15)),
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
                      title: const Text('Country / Region', style: TextStyle(color: Colors.white, fontSize: 15)),
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
                      title: const Text('Location Access', style: TextStyle(color: Colors.white, fontSize: 15)),
                      trailing: Text('Enabled', style: TextStyle(color: Colors.grey[400], fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                    const Divider(height: 1, color: Color(0xFF2C2C2E)),
                    ListTile(
                      leading: const Icon(Icons.lock_outline, color: Colors.white),
                      title: const Text('Change Password', style: TextStyle(color: Colors.white, fontSize: 15)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
                        );
                      },
                    ),
                    const Divider(height: 1, color: Color(0xFF2C2C2E)),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined, color: Colors.white),
                      title: const Text('Privacy Policy', style: TextStyle(color: Colors.white, fontSize: 15)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                        );
                      },
                    ),
                    const Divider(height: 1, color: Color(0xFF2C2C2E)),
                    ListTile(
                      leading: const Icon(Icons.info_outline, color: Colors.white),
                      title: const Text('About Roost', style: TextStyle(color: Colors.white, fontSize: 15)),
                      subtitle: Text('v1.0.0 · ${CountryService.config.name}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AboutRoostPage()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Sign Out Button (Red Text)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: TextButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  Widget _buildMenuItemWithBadge(IconData icon, String title, int badgeCount, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badgeCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            if (badgeCount > 0) const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
        onTap: onTap,
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
