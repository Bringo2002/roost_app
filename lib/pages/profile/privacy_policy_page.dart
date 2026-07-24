import 'package:flutter/material.dart';

/// Production-ready Privacy Policy page for Roost.
/// Displays the full privacy policy in-app with clean typography and
/// section-based navigation. Dark theme consistent with the rest of the app.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const String _lastUpdated = 'July 24, 2026';

  @override
  Widget build(BuildContext context) {
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
          'Privacy Policy',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    child: const Icon(Icons.privacy_tip_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Roost Privacy Policy',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Last updated: $_lastUpdated',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildParagraph(
              'Roost Technologies Ltd ("Roost", "we", "us", or "our") operates the Roost '
              'mobile application (the "App"). This Privacy Policy explains how we collect, '
              'use, disclose, and safeguard your personal information when you use our App.',
            ),

            const SizedBox(height: 24),

            _buildSection(
              '1. Information We Collect',
              [
                _buildSubSection(
                  'Account Information',
                  'When you create an account, we collect your name, email address, phone number, '
                  'and account role (tenant or landlord). Landlords also provide property details '
                  'including listing descriptions, photographs, pricing, and location data.',
                ),
                _buildSubSection(
                  'Usage Data',
                  'We automatically collect information about how you interact with the App, '
                  'including pages viewed, search queries, saved properties, bookings, and '
                  'in-app messages. This data helps us improve the App experience.',
                ),
                _buildSubSection(
                  'Device & Technical Data',
                  'We collect device type, operating system version, unique device identifiers, '
                  'IP address, and push notification tokens to deliver notifications and ensure '
                  'compatibility.',
                ),
                _buildSubSection(
                  'Location Data',
                  'With your permission, we access your device location to show nearby listings, '
                  'calculate distances, and display map-based search results. You can disable '
                  'location access at any time through your device settings.',
                ),
              ],
            ),

            _buildSection(
              '2. How We Use Your Information',
              [
                _buildBulletList([
                  'To create and manage your account',
                  'To display relevant property listings based on your preferences and location',
                  'To facilitate communication between tenants and landlords via in-app messaging',
                  'To process booking requests and applications',
                  'To send push notifications about new listings, booking updates, and messages',
                  'To improve, personalise, and optimise the App experience',
                  'To detect and prevent fraud, abuse, and security incidents',
                  'To comply with legal obligations and enforce our Terms of Service',
                ]),
              ],
            ),

            _buildSection(
              '3. How We Share Your Information',
              [
                _buildParagraph(
                  'We do not sell your personal information. We may share your data in the '
                  'following limited circumstances:',
                ),
                _buildBulletList([
                  'With landlords or tenants: Your name and contact details are shared when you '
                      'initiate a chat, submit a booking request, or apply for a property.',
                  'With service providers: We use trusted third-party services for hosting, '
                      'analytics, push notifications, and payment processing. These providers '
                      'only access data necessary to perform their services.',
                  'For legal compliance: We may disclose information when required by law, '
                      'court order, or to protect the rights, safety, or property of Roost or its users.',
                ]),
              ],
            ),

            _buildSection(
              '4. Data Storage & Security',
              [
                _buildParagraph(
                  'Your data is stored on secure servers. We implement industry-standard '
                  'security measures including encryption in transit (TLS/SSL), secure '
                  'authentication (JWT tokens), and access controls. However, no method of '
                  'electronic storage is 100% secure, and we cannot guarantee absolute security.',
                ),
              ],
            ),

            _buildSection(
              '5. Data Retention',
              [
                _buildParagraph(
                  'We retain your personal data for as long as your account is active or as '
                  'needed to provide you services. If you delete your account, we will remove '
                  'your personal data within 30 days, except where retention is required by law '
                  'or for legitimate business purposes (e.g., resolving disputes).',
                ),
              ],
            ),

            _buildSection(
              '6. Your Rights',
              [
                _buildParagraph(
                  'Depending on your jurisdiction, you may have the following rights regarding '
                  'your personal data:',
                ),
                _buildBulletList([
                  'Access: Request a copy of the personal data we hold about you.',
                  'Correction: Request correction of inaccurate or incomplete data.',
                  'Deletion: Request deletion of your account and associated data.',
                  'Portability: Request your data in a structured, machine-readable format.',
                  'Opt-out: Disable push notifications, location access, or marketing '
                      'communications at any time.',
                ]),
                _buildParagraph(
                  'To exercise any of these rights, contact us at privacy@roost.co.ke.',
                ),
              ],
            ),

            _buildSection(
              '7. Children\'s Privacy',
              [
                _buildParagraph(
                  'The App is not intended for use by individuals under the age of 18. We do '
                  'not knowingly collect personal data from children. If we become aware that '
                  'we have collected data from a child under 18, we will delete it promptly.',
                ),
              ],
            ),

            _buildSection(
              '8. Third-Party Links',
              [
                _buildParagraph(
                  'The App may contain links to third-party websites or services (e.g., maps, '
                  'social media). We are not responsible for the privacy practices of these '
                  'third parties. We encourage you to review their privacy policies.',
                ),
              ],
            ),

            _buildSection(
              '9. Changes to This Policy',
              [
                _buildParagraph(
                  'We may update this Privacy Policy from time to time. We will notify you of '
                  'material changes through the App or by email. Your continued use of the App '
                  'after changes constitutes acceptance of the updated policy.',
                ),
              ],
            ),

            _buildSection(
              '10. Contact Us',
              [
                _buildParagraph(
                  'If you have questions, concerns, or requests regarding this Privacy Policy '
                  'or your personal data, please contact us:',
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2C2C2E)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildContactRow(Icons.business_rounded, 'Roost Technologies Ltd'),
                      const SizedBox(height: 10),
                      _buildContactRow(Icons.email_outlined, 'privacy@roost.co.ke'),
                      const SizedBox(height: 10),
                      _buildContactRow(Icons.language_rounded, 'www.roost.co.ke'),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  static Widget _buildSection(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  static Widget _buildSubSection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildParagraph(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.grey[400],
        fontSize: 14,
        height: 1.6,
      ),
    );
  }

  static Widget _buildBulletList(List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  static Widget _buildContactRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 18),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ],
    );
  }
}
