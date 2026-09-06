import 'package:flutter/material.dart';
import 'package:roost_app/pages/landlord/add_property_page.dart';

class ListingIntroPage extends StatefulWidget {
  const ListingIntroPage({super.key});

  @override
  State<ListingIntroPage> createState() => _ListingIntroPageState();
}

class _ListingIntroPageState extends State<ListingIntroPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  static const _requirements = [
    (
      icon: Icons.photo_library_outlined,
      color: Color(0xFF6C63FF),
      title: 'A few clear photos',
      subtitle: 'At least 3 shots — your first becomes the cover',
    ),
    (
      icon: Icons.my_location,
      color: Color(0xFF00C896),
      title: 'Your exact GPS location',
      subtitle: 'Stand at the property — this earns your Verified badge',
    ),
    (
      icon: Icons.sell_outlined,
      color: Color(0xFFFF9F43),
      title: 'Price & basic details',
      subtitle: 'Rent amount, bedrooms, and house type',
    ),
    (
      icon: Icons.phone_iphone,
      color: Color(0xFF4FC3F7),
      title: 'A contact phone number',
      subtitle: 'So renters can reach you directly',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Animation<double> _itemAnimation(int index) {
    final start = index * 0.15;
    final end = (start + 0.55).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _ctrl,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  Animation<double> _headerAnimation() => CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      );

  Animation<double> _buttonAnimation() => CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOutCubic),
      );

  @override
  Widget build(BuildContext context) {
    final headerAnim = _headerAnimation();
    final buttonAnim = _buttonAnimation();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Subtle radial glow
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // Animated header
                  AnimatedBuilder(
                    animation: headerAnim,
                    builder: (context, child) => Opacity(
                      opacity: headerAnim.value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - headerAnim.value)),
                        child: child,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timer_outlined,
                                  size: 13, color: Colors.white70),
                              const SizedBox(width: 6),
                              Text(
                                'About 5 minutes',
                                style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'List your\nproperty',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "We'll walk you through it step by step.\nHere's what you'll want ready:",
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 15, height: 1.5),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),

                  Expanded(
                    child: ListView.separated(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _requirements.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, i) {
                        final item = _requirements[i];
                        final anim = _itemAnimation(i);
                        return AnimatedBuilder(
                          animation: anim,
                          builder: (context, child) => Opacity(
                            opacity: anim.value,
                            child: Transform.translate(
                              offset: Offset(24 * (1 - anim.value), 0),
                              child: child,
                            ),
                          ),
                          child: _RequirementRow(
                            icon: item.icon,
                            iconColor: item.color,
                            title: item.title,
                            subtitle: item.subtitle,
                          ),
                        );
                      },
                    ),
                  ),

                  // Animated CTA
                  AnimatedBuilder(
                    animation: buttonAnim,
                    builder: (context, child) => Opacity(
                      opacity: buttonAnim.value,
                      child: Transform.translate(
                        offset: Offset(0, 16 * (1 - buttonAnim.value)),
                        child: child,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24, top: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AddPropertyPage()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 17),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Let's get started",
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.2),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: iconColor.withValues(alpha: 0.22)),
          ),
          child: Icon(icon, color: iconColor, size: 21),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                    color: Colors.grey[500], fontSize: 13, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
