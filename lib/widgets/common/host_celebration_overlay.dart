import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// FAANG-grade celebration overlay shown when a user becomes a host.
///
/// Features:
/// - Full-screen confetti particle system (custom painter, no packages)
/// - Staggered entrance animations for every element
/// - Glassmorphic card with gradient accents
/// - Personalized greeting and clear next-step CTA
class HostCelebrationOverlay extends StatefulWidget {
  const HostCelebrationOverlay({
    super.key,
    required this.userName,
    required this.onContinue,
  });

  /// First name or display name of the new host.
  final String userName;

  /// Called when the user taps the primary CTA ("Go to Dashboard").
  final VoidCallback onContinue;

  /// Show the overlay as a full-screen modal route.
  static Future<void> show(
    BuildContext context, {
    required String userName,
    required VoidCallback onContinue,
  }) {
    HapticFeedback.heavyImpact();
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => HostCelebrationOverlay(
        userName: userName,
        onContinue: onContinue,
      ),
      transitionBuilder: (context, animation, _, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }

  @override
  State<HostCelebrationOverlay> createState() => _HostCelebrationOverlayState();
}

class _HostCelebrationOverlayState extends State<HostCelebrationOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _confettiController;
  late final AnimationController _contentController;

  // Staggered content animations
  late final Animation<double> _iconScale;
  late final Animation<double> _iconOpacity;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _subtitleSlide;
  late final Animation<double> _subtitleOpacity;
  late final Animation<Offset> _featureSlide;
  late final Animation<double> _featureOpacity;
  late final Animation<double> _buttonScale;
  late final Animation<double> _buttonOpacity;
  late final Animation<double> _shimmer;

  late final List<_ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();

    // ── Confetti ──────────────────────────────────────────────────────────
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..forward();

    final rng = Random();
    _particles = List.generate(80, (_) => _ConfettiParticle(rng));

    // ── Content stagger ──────────────────────────────────────────────────
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();

    _iconScale = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: const Interval(0.0, 0.30, curve: Curves.elasticOut)),
    );
    _iconOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: const Interval(0.0, 0.20, curve: Curves.easeOut)),
    );

    _titleSlide = Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _contentController, curve: const Interval(0.15, 0.40, curve: Curves.easeOutCubic)),
    );
    _titleOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: const Interval(0.15, 0.35, curve: Curves.easeOut)),
    );

    _subtitleSlide = Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _contentController, curve: const Interval(0.25, 0.50, curve: Curves.easeOutCubic)),
    );
    _subtitleOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: const Interval(0.25, 0.45, curve: Curves.easeOut)),
    );

    _featureSlide = Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _contentController, curve: const Interval(0.40, 0.65, curve: Curves.easeOutCubic)),
    );
    _featureOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: const Interval(0.40, 0.60, curve: Curves.easeOut)),
    );

    _buttonScale = Tween(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: const Interval(0.60, 0.85, curve: Curves.elasticOut)),
    );
    _buttonOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: const Interval(0.60, 0.75, curve: Curves.easeOut)),
    );

    _shimmer = Tween(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _contentController, curve: const Interval(0.70, 1.0, curve: Curves.easeInOut)),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final firstName = widget.userName.split(' ').first;

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Confetti layer ────────────────────────────────────────────
          AnimatedBuilder(
            animation: _confettiController,
            builder: (context, _) => CustomPaint(
              size: screenSize,
              painter: _ConfettiPainter(
                particles: _particles,
                progress: _confettiController.value,
              ),
            ),
          ),

          // ── Content layer ────────────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                child: AnimatedBuilder(
                  animation: _contentController,
                  builder: (context, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Celebration icon
                      Opacity(
                        opacity: _iconOpacity.value,
                        child: Transform.scale(
                          scale: _iconScale.value,
                          child: Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                                  blurRadius: 32,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.home_work_rounded, color: Colors.white, size: 44),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Title
                      SlideTransition(
                        position: _titleSlide,
                        child: Opacity(
                          opacity: _titleOpacity.value,
                          child: Column(
                            children: [
                              Text(
                                'Welcome, $firstName! 🎉',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: const [Color(0xFF818CF8), Color(0xFFC084FC), Color(0xFF818CF8)],
                                  stops: [
                                    (_shimmer.value - 0.3).clamp(0.0, 1.0),
                                    _shimmer.value.clamp(0.0, 1.0),
                                    (_shimmer.value + 0.3).clamp(0.0, 1.0),
                                  ],
                                ).createShader(bounds),
                                child: const Text(
                                  'You\'re officially a Roost Host',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Subtitle
                      SlideTransition(
                        position: _subtitleSlide,
                        child: Opacity(
                          opacity: _subtitleOpacity.value,
                          child: const Text(
                            'Your hosting dashboard is ready. List your first property and start connecting with verified tenants.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFA1A1AA),
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Feature pills
                      SlideTransition(
                        position: _featureSlide,
                        child: Opacity(
                          opacity: _featureOpacity.value,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Column(
                              children: [
                                _featureRow(Icons.add_home_rounded, 'List unlimited properties'),
                                const SizedBox(height: 14),
                                _featureRow(Icons.verified_rounded, 'Get verified host badges'),
                                const SizedBox(height: 14),
                                _featureRow(Icons.chat_bubble_rounded, 'Chat directly with tenants'),
                                const SizedBox(height: 14),
                                _featureRow(Icons.analytics_rounded, 'Track views & engagement'),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 36),

                      // CTA button
                      Opacity(
                        opacity: _buttonOpacity.value,
                        child: Transform.scale(
                          scale: _buttonScale.value,
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: () {
                                  HapticFeedback.mediumImpact();
                                  Navigator.of(context).pop();
                                  widget.onContinue();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Go to Host Dashboard',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          ),
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

  Widget _featureRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF818CF8), size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFFE4E4E7),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Icon(Icons.check_circle_rounded, color: Color(0xFF6366F1), size: 18),
      ],
    );
  }
}

// ─── Confetti Particle System ────────────────────────────────────────────────

class _ConfettiParticle {
  _ConfettiParticle(Random rng)
      : x = rng.nextDouble(),
        delay = rng.nextDouble() * 0.3,
        speed = 0.5 + rng.nextDouble() * 0.8,
        drift = (rng.nextDouble() - 0.5) * 0.4,
        size = 4 + rng.nextDouble() * 6,
        rotation = rng.nextDouble() * pi * 2,
        rotationSpeed = (rng.nextDouble() - 0.5) * 8,
        color = _confettiColors[rng.nextInt(_confettiColors.length)],
        isCircle = rng.nextBool();

  final double x;
  final double delay;
  final double speed;
  final double drift;
  final double size;
  final double rotation;
  final double rotationSpeed;
  final Color color;
  final bool isCircle;

  static const _confettiColors = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF8B5CF6), // Purple
    Color(0xFFA78BFA), // Light purple
    Color(0xFFC084FC), // Pink-purple
    Color(0xFFF472B6), // Pink
    Color(0xFF38BDF8), // Sky blue
    Color(0xFF34D399), // Emerald
    Color(0xFFFBBF24), // Amber
    Color(0xFFFFFFFF), // White
  ];
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.particles, required this.progress});

  final List<_ConfettiParticle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = ((progress - p.delay) / (1.0 - p.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;

      // Fade out in the last 30%
      final opacity = t > 0.7 ? ((1.0 - t) / 0.3).clamp(0.0, 1.0) : 1.0;

      final px = p.x * size.width + sin(t * pi * 3) * p.drift * size.width;
      final py = -p.size + t * (size.height + p.size * 2) * p.speed;

      final paint = Paint()..color = p.color.withValues(alpha: opacity * 0.85);

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.rotation + t * p.rotationSpeed);

      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        // Small rounded rectangle
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
            const Radius.circular(1.5),
          ),
          paint,
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
