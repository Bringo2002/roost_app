import 'package:flutter/material.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/auth_service.dart';
import 'package:roost_app/pages/welcome_page.dart';

import 'package:roost_app/pages/landlord_dashboard_page.dart';
import 'package:roost_app/pages/booking_history_page.dart';
import 'package:roost_app/pages/saved_page.dart';
import 'package:roost_app/pages/applications_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
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
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $_error', style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 16),
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
    final role = _user?['role'] ?? 'TENANT';
    final initials = name.isNotEmpty
        ? name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '?';

    final isLandlord = role.toString().toUpperCase() == 'LANDLORD';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 24),

          // Avatar
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Name
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 4),

          // Email
          Text(
            email,
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),

          const SizedBox(height: 8),

          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[700]!),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              role.toString().toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1),
            ),
          ),

          const SizedBox(height: 40),

          // Menu items
          if (isLandlord)
            _buildMenuItem(Icons.business_center_outlined, 'My Listings', () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const LandlordDashboardPage()));
            })
          else ...[
            _buildMenuItem(Icons.receipt_long_outlined, 'My Bookings', () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const BookingHistoryPage()));
            }),
            _buildMenuItem(Icons.favorite_border, 'Saved Properties', () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedPage()));
            }),
            _buildMenuItem(Icons.assignment_outlined, 'My Applications', () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ApplicationsPage()));
            }),
          ],
          _buildMenuItem(Icons.notifications_none, 'Notifications', () {
            // TODO: Notifications page
          }),
          _buildMenuItem(Icons.help_outline, 'Help & Support', () {
            // TODO: Support page
          }),
          _buildMenuItem(Icons.info_outline, 'About Roost', () {
            showAboutDialog(
              context: context,
              applicationName: 'Roost',
              applicationVersion: '1.0.0',
              applicationLegalese: '© 2026 Roost. All rights reserved.',
            );
          }),

          const SizedBox(height: 24),

          // Logout
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, size: 20),
              label: const Text(
                'Log Out',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.grey[800]!),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey[900]!, width: 1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[700], size: 20),
          ],
        ),
      ),
    );
  }
}
