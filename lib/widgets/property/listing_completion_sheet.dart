import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/pages/search/property_detail_page.dart';
import 'package:roost_app/services/country_service.dart';

/// FAANG-inspired host completion modal sheet with custom confetti celebration,
/// property snapshot card, and quick host actions (Preview, Share, Done).
class ListingCompletionSheet extends StatefulWidget {
  const ListingCompletionSheet({
    super.key,
    required this.property,
    required this.isEditing,
  });

  final Property property;
  final bool isEditing;

  static Future<void> show(
    BuildContext context, {
    required Property property,
    required bool isEditing,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ListingCompletionSheet(
        property: property,
        isEditing: isEditing,
      ),
    );
  }

  @override
  State<ListingCompletionSheet> createState() => _ListingCompletionSheetState();
}

class _ListingCompletionSheetState extends State<ListingCompletionSheet>
    with TickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final AnimationController _confettiCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  late final List<_ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _scaleAnim = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.elasticOut,
    );

    _fadeAnim = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );

    _particles = List.generate(45, (i) => _ConfettiParticle.random());

    _entranceCtrl.forward();
    _confettiCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  void _shareListing() {
    HapticFeedback.selectionClick();
    final symbol = CountryService.config.currencySymbol;
    final priceStr = widget.property.price > 0
        ? '$symbol ${widget.property.price.toInt()}'
        : '';
    final text = 'Check out my property on Roost: "${widget.property.title}" '
        'in ${widget.property.location} $priceStr/mo!\n'
        'Download Roost to schedule viewings & submit applications.';
    Share.share(text);
  }

  void _previewListing() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PropertyDetailPage(property: widget.property),
      ),
    );
  }

  void _finish() {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final symbol = CountryService.config.currencySymbol;
    final displayImage = widget.property.imageUrls.isNotEmpty
        ? widget.property.imageUrls.first
        : widget.property.imageUrl;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Confetti particle overlay
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _confettiCtrl,
              builder: (context, child) {
                return CustomPaint(
                  painter: _ConfettiPainter(
                    progress: _confettiCtrl.value,
                    particles: _particles,
                  ),
                );
              },
            ),
          ),

          // Main Card
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF141416),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFF00C896).withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00C896).withValues(alpha: 0.15),
                  blurRadius: 32,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.8),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Status Badge Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C896).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF00C896).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF00C896),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.isEditing ? 'LISTING UPDATED' : 'LIVE ON ROOST',
                          style: const TextStyle(
                            color: Color(0xFF00C896),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Animated Checkmark Icon Halo
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF00C896).withValues(alpha: 0.25),
                            const Color(0xFF00C896).withValues(alpha: 0.05),
                          ],
                        ),
                        border: Border.all(
                          color: const Color(0xFF00C896).withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.check_rounded,
                          color: Color(0xFF00C896),
                          size: 46,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Headline & Description Text
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      children: [
                        Text(
                          widget.isEditing
                              ? 'Changes Are Live! ✨'
                              : 'You\'re Live on Roost! 🚀',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.isEditing
                              ? 'Your property updates have been successfully synced across Roost.'
                              : 'Your property is now visible to thousands of verified renters searching in your area.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13.5,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Embedded Property Snapshot Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E22),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        // Property Thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 72,
                            height: 72,
                            child: displayImage != null && displayImage.isNotEmpty
                                ? Image.network(
                                    displayImage,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _buildFallbackThumbnail(),
                                  )
                                : _buildFallbackThumbnail(),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Property Meta Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.property.title.isNotEmpty
                                    ? widget.property.title
                                    : 'Untitled Property',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.location_on_outlined,
                                      size: 13, color: Colors.grey[400]),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      widget.property.location.isNotEmpty
                                          ? widget.property.location
                                          : 'Location set',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    '$symbol ${widget.property.price.toInt()}',
                                    style: const TextStyle(
                                      color: Color(0xFF00C896),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    ' / mo',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (widget.property.bedrooms > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${widget.property.bedrooms} Bed',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Actions Group
                  Column(
                    children: [
                      // Primary Button: Preview Live Listing
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _previewListing,
                          icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                          label: const Text('Preview Live Listing'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Secondary Button: Share Listing
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _shareListing,
                          icon: const Icon(Icons.share_outlined, size: 18),
                          label: const Text('Share Listing Link'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Tertiary Button: Return to My Properties
                      TextButton.icon(
                        onPressed: _finish,
                        icon: Icon(Icons.dashboard_outlined,
                            size: 16, color: Colors.grey[400]),
                        label: Text(
                          'Return to My Properties',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackThumbnail() {
    return Container(
      color: const Color(0xFF2C2C32),
      child: const Center(
        child: Icon(
          Icons.home_work_outlined,
          color: Color(0xFF00C896),
          size: 32,
        ),
      ),
    );
  }
}

// ── Particle Confetti Custom Painter ────────────────────────────────────────

class _ConfettiParticle {
  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.color,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.vr,
    required this.isCircle,
  });

  final double x; // ratio 0..1
  final double y; // ratio 0..1
  final double size;
  final Color color;
  final double vx;
  final double vy;
  final double rotation;
  final double vr;
  final bool isCircle;

  static final _rnd = math.Random();
  static const _palette = [
    Color(0xFF00C896), // Emerald
    Color(0xFFFFD700), // Gold
    Color(0xFF6C63FF), // Indigo
    Color(0xFFFF6B6B), // Coral
    Color(0xFF00E5FF), // Cyan
    Colors.white,
  ];

  factory _ConfettiParticle.random() {
    final angle = _rnd.nextDouble() * math.pi * 2;
    final speed = 1.5 + _rnd.nextDouble() * 3.5;
    return _ConfettiParticle(
      x: 0.5 + (_rnd.nextDouble() - 0.5) * 0.2,
      y: 0.3 + (_rnd.nextDouble() - 0.5) * 0.1,
      size: 5 + _rnd.nextDouble() * 7,
      color: _palette[_rnd.nextInt(_palette.length)],
      vx: math.cos(angle) * speed,
      vy: (math.sin(angle) * speed) - 2.5,
      rotation: _rnd.nextDouble() * math.pi * 2,
      vr: (_rnd.nextDouble() - 0.5) * 0.2,
      isCircle: _rnd.nextBool(),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.progress,
    required this.particles,
  });

  final double progress;
  final List<_ConfettiParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    for (final p in particles) {
      final px = (p.x * size.width) + (p.vx * progress * 60);
      final py = (p.y * size.height) + (p.vy * progress * 80) + (progress * progress * 120);
      final rot = p.rotation + (p.vr * progress * 10);

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(rot);

      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          ),
          paint,
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
