import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/country_service.dart';
import 'package:roost_app/services/rent_estimator_service.dart';
import 'package:roost_app/theme/app_colors.dart';

/// Displays an interactive AI-driven market price index gauge for a property,
/// showing where the listing price falls relative to comparable rentals in
/// the same area and house type.
class MarketPriceIndexCard extends StatefulWidget {
  const MarketPriceIndexCard({super.key, required this.property});

  final Property property;

  @override
  State<MarketPriceIndexCard> createState() => _MarketPriceIndexCardState();
}

class _MarketPriceIndexCardState extends State<MarketPriceIndexCard>
    with SingleTickerProviderStateMixin {
  RentEstimate? _estimate;
  bool _loading = true;
  bool _failed = false;

  late final AnimationController _gaugeAnim;
  late final Animation<double> _gaugeCurve;

  final _fmt = NumberFormat('#,##0', 'en_US');

  @override
  void initState() {
    super.initState();
    _gaugeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _gaugeCurve = CurvedAnimation(parent: _gaugeAnim, curve: Curves.easeOutCubic);
    _fetchEstimate();
  }

  @override
  void dispose() {
    _gaugeAnim.dispose();
    super.dispose();
  }

  Future<void> _fetchEstimate() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final est = await RentEstimatorService.estimate(widget.property);
      if (!mounted) return;
      setState(() {
        _estimate = est;
        _loading = false;
        _failed = est == null;
      });
      if (est != null) _gaugeAnim.forward();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  String _fmtPrice(double v) => '${CountryService.config.currencySymbol} ${_fmt.format(v)}';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: _loading
          ? _buildLoading()
          : _failed
              ? _buildFailed()
              : _buildContent(),
    );
  }

  // ── Loading State ─────────────────────────────────────────────────────────
  Widget _buildLoading() {
    return Column(
      children: [
        const Row(
          children: [
            Icon(Icons.analytics_outlined, color: AppColors.white, size: 22),
            SizedBox(width: 8),
            Text(
              'AI Market Analysis',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.grey[400],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Analyzing comparable listings...',
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── Failed / Not Enough Data State ────────────────────────────────────────
  Widget _buildFailed() {
    return Column(
      children: [
        const Row(
          children: [
            Icon(Icons.analytics_outlined, color: AppColors.grey500, size: 22),
            SizedBox(width: 8),
            Text(
              'AI Market Analysis',
              style: TextStyle(
                color: AppColors.grey400,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.grey500, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Not enough comparable listings in this area yet to generate a market estimate.',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Main Content ──────────────────────────────────────────────────────────
  Widget _buildContent() {
    final est = _estimate!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics_outlined, color: AppColors.white, size: 22),
                SizedBox(width: 8),
                Text(
                  'AI Market Analysis',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                '${est.comparableCount} comps',
                style: TextStyle(color: Colors.grey[400], fontSize: 11),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── Rating Badge ──────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                est.ratingColor.withValues(alpha: 0.15),
                est.ratingColor.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: est.ratingColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Text(est.ratingEmoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      est.ratingLabel,
                      style: TextStyle(
                        color: est.ratingColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _ratingSubtitle(est),
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // ── Price Gauge Bar ─────────────────────────────────────────────────
        AnimatedBuilder(
          animation: _gaugeCurve,
          builder: (context, _) => _buildPriceGauge(est),
        ),

        const SizedBox(height: 20),

        // ── Market Range Stats ──────────────────────────────────────────────
        Row(
          children: [
            _buildStatChip('Low', _fmtPrice(est.minPrice), const Color(0xFF10B981)),
            const SizedBox(width: 8),
            _buildStatChip('Median', _fmtPrice(est.medianPrice), const Color(0xFF38BDF8)),
            const SizedBox(width: 8),
            _buildStatChip('High', _fmtPrice(est.maxPrice), Colors.amber),
          ],
        ),

        // ── Value Drivers ──────────────────────────────────────────────────
        if (est.valueDrivers.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'VALUE DRIVERS',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          for (final driver in est.valueDrivers) _buildDriverRow(driver),
        ],
      ],
    );
  }

  // ── Price Gauge Visualization ─────────────────────────────────────────────
  Widget _buildPriceGauge(RentEstimate est) {
    final animatedPercentile = est.percentile * _gaugeCurve.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PRICE POSITION',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 42,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final pinPos = (animatedPercentile * width).clamp(12.0, width - 12.0);

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Background track
                  Positioned(
                    top: 26,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF10B981), // Green (great deal)
                            Color(0xFF38BDF8), // Blue (fair)
                            Color(0xFFFBBF24), // Amber (above market)
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Filled portion
                  Positioned(
                    top: 26,
                    left: 0,
                    child: Container(
                      height: 8,
                      width: pinPos,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: est.ratingColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  // Pin indicator
                  Positioned(
                    top: 0,
                    left: pinPos - 12,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: est.ratingColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${(est.percentile * 100).round()}th',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Icon(Icons.arrow_drop_down, color: est.ratingColor, size: 16),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Lower', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
            Text('Neighborhood Average', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
            Text('Higher', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverRow(ValueDriver driver) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: driver.isPositive
                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                  : Colors.amber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              driver.isPositive ? Icons.trending_up : Icons.trending_down,
              color: driver.isPositive ? const Color(0xFF10B981) : Colors.amber,
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              driver.label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            driver.impact,
            style: TextStyle(
              color: driver.isPositive ? const Color(0xFF10B981) : Colors.amber,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _ratingSubtitle(RentEstimate est) {
    switch (est.rating) {
      case 'GREAT_DEAL':
        return 'This rent is below the area median — strong value for tenants.';
      case 'FAIR_PRICE':
        return 'This rent aligns with comparable listings in the neighborhood.';
      case 'ABOVE_MARKET':
        return 'This rent is above most comparables — premium positioning.';
      default:
        return '';
    }
  }
}
