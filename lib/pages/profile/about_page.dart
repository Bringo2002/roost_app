import 'package:flutter/material.dart';
import 'package:roost_app/services/country_service.dart';

/// Production-ready "About Roost" page displaying app information,
/// core mission, key features, platform stats, open-source licenses,
/// and official contact channels.
class AboutRoostPage extends StatelessWidget {
  const AboutRoostPage({super.key});

  static const String _version = '1.0.0';
  static const String _buildNumber = '104';

  @override
  Widget build(BuildContext context) {
    final activeCountry = CountryService.config;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'About Roost',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            const SizedBox(height: 12),

            // App Brand Hero Badge
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF2C2C2E)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.15),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.home_work_rounded,
                        color: Colors.black,
                        size: 44,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ROOST',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Modern Housing & Rental Discovery',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      'Version $_version ($_buildNumber)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Mission Statement
            _buildCard(
              title: 'OUR MISSION',
              child: Text(
                'Roost is designed to make finding, booking, and renting homes completely seamless. '
                'We connect tenants directly with verified property owners, eliminating hidden fees and '
                'simplifying property search across Kenya and East Africa.',
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Key Platform Features
            _buildCard(
              title: 'KEY FEATURES',
              child: Column(
                children: [
                  _buildFeatureTile(
                    icon: Icons.verified_user_rounded,
                    title: 'Verified Property Listings',
                    subtitle: 'All listings are vetted for authenticity to protect renters.',
                  ),
                  const Divider(height: 20, color: Color(0xFF2C2C2E)),
                  _buildFeatureTile(
                    icon: Icons.forum_rounded,
                    title: 'Direct Landlord Messaging',
                    subtitle: 'Chat directly with property managers with real-time updates.',
                  ),
                  const Divider(height: 20, color: Color(0xFF2C2C2E)),
                  _buildFeatureTile(
                    icon: Icons.map_rounded,
                    title: 'Interactive Map Search',
                    subtitle: 'Explore rentals by location, neighborhood, and nearby points of interest.',
                  ),
                  const Divider(height: 20, color: Color(0xFF2C2C2E)),
                  _buildFeatureTile(
                    icon: Icons.currency_exchange_rounded,
                    title: 'Multi-Country & Currency Support',
                    subtitle: 'Tailored for ${activeCountry.name} (${activeCountry.currencyCode}) and regional markets.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // System Information & Region
            _buildCard(
              title: 'APP ENVIRONMENT',
              child: Column(
                children: [
                  _buildInfoRow('Active Region', '${activeCountry.flag} ${activeCountry.name}'),
                  const SizedBox(height: 10),
                  _buildInfoRow('Currency', '${activeCountry.currencyCode} (${activeCountry.currencySymbol})'),
                  const SizedBox(height: 10),
                  _buildInfoRow('Release Status', 'Production Stable'),
                  const SizedBox(height: 10),
                  _buildInfoRow('Platform', 'Android & iOS'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Open Source & Legal Actions
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2C2C2E)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.code_rounded, color: Colors.white),
                    title: const Text(
                      'Open Source Licenses',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () {
                      showLicensePage(
                        context: context,
                        applicationName: 'Roost',
                        applicationVersion: 'v$_version',
                        applicationIcon: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.home_work_rounded, color: Colors.black, size: 36),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Footer / Copyright
            Text(
              '© ${DateTime.now().year} Roost Technologies Ltd.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              'All rights reserved.',
              style: TextStyle(color: Colors.grey[700], fontSize: 11),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[400], fontSize: 13),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
