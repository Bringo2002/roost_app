import 'package:flutter/material.dart';
import 'package:roost_app/pages/landlord/add_property_page.dart';
import 'package:roost_app/widgets/common/roost_logo_icon.dart';

/// Shown once, before a brand-new listing wizard starts (never for
/// editing an existing one -- returning landlords don't need re-orienting).
/// Sets expectations up front: what's needed, roughly how long it takes,
/// and why a couple of the steps matter, so nothing in the wizard itself
/// comes as a surprise.
class ListingIntroPage extends StatelessWidget {
  const ListingIntroPage({super.key});

  static const _requirements = [
    (
      icon: Icons.photo_library_outlined,
      title: 'A few clear photos',
      subtitle: 'At least 3 -- your first becomes the cover photo',
    ),
    (
      icon: Icons.my_location,
      title: 'Your exact location',
      subtitle: "Captured automatically from your GPS while you're at the property -- this earns the Verified badge",
    ),
    (
      icon: Icons.sell_outlined,
      title: 'Price and basic details',
      subtitle: 'Rent, bedrooms, house type',
    ),
    (
      icon: Icons.phone_iphone,
      title: 'A verified phone number',
      subtitle: "So renters can reach you, and so we know it's really you",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const RoostLogoIcon(size: 56),
              const SizedBox(height: 24),
              const Text(
                'List your property',
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Takes about 5 minutes. We'll walk you through it step by step -- here's what you'll want ready.",
                style: TextStyle(color: Colors.grey[400], fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView.separated(
                  itemCount: _requirements.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 18),
                  itemBuilder: (context, i) {
                    final item = _requirements[i];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(item.icon, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.subtitle,
                                style: TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 24, top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const AddPropertyPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Get Started', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
