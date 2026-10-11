import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/country_service.dart';
import 'package:roost_app/services/rent_estimator_service.dart';
import 'package:roost_app/theme/app_colors.dart';

/// Displays an interactive market price index gauge for a property,
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

  static final _fmt = NumberFormat('#,##0', 'en_US');

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
    return Shimmer.fromColors(
      baseColor: AppColors.grey800,
      highlightColor: AppColors.grey700,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 22, height: 22, decoration: const BoxDecoration(color: AppColors.grey800, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Container(width: 160, height: 16, decoration: BoxDecoration(color: AppColors.grey800, borderRadius: BorderRadius.circular(4))),
            ],
          ),
          const SizedBox(height: 16),
          Container(width: double.infinity, height: 72, decoration: BoxDecoration(color: AppColors.grey800, borderRadius: BorderRadius.circular(16))),
          const SizedBox(height: 18),
          Container(width: 100, height: 10, decoration: BoxDecoration(color: AppColors.grey800, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 10),
          Container(width: double.infinity, height: 8, decoration: BoxDecoration(color: AppColors.grey800, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Container(height: 48, decoration: BoxDecoration(color: AppColors.grey800, borderRadius: BorderRadius.circular(12)))),
              const SizedBox(width: 8),
              Expanded(child: Container(height: 48, decoration: BoxDecoration(color: AppColors.grey800, borderRadius: BorderRadius.circular(12)))),
              const SizedBox(width: 8),
              Expanded(child: Container(height: 48, decoration: BoxDecoration(color: AppColors.grey800, borderRadius: BorderRadius.circular(12)))),
            ],
          ),
        ],
      ),
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
              'Market Price Analysis',
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
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.grey500, size: 16),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Not enough comparable listings in this area yet to generate a market estimate.',
                  style: TextStyle(color: AppColors.grey400, fontSize: 12),
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
                  'Market Price Analysis',
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
                style: const TextStyle(color: AppColors.grey400, fontSize: 11),
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
                est.rating.color.withAlpha(38),
                est.rating.color.withAlpha(13),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: est.rating.color.withAlpha(77)),
          ),
          child: Row(
            children: [
              Text(est.rating.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      est.rating.label,
                      style: TextStyle(
                        color: est.rating.color,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      est.rating.subtitle,
                      style: const TextStyle(color: AppColors.grey400, fontSize: 12),
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
            _StatChip(label: 'Low', value: _fmtPrice(est.minPrice)),
            const SizedBox(width: 8),
            _StatChip(label: 'Median', value: _fmtPrice(est.medianPrice)),
            const SizedBox(width: 8),
            _StatChip(label: 'High', value: _fmtPrice(est.maxPrice)),
          ],
        ),

        // ── Value Drivers ──────────────────────────────────────────────────
        if (est.valueDrivers.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'VALUE DRIVERS',
            style: TextStyle(
              color: AppColors.grey500,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          for (final driver in est.valueDrivers)
            _DriverRow(driver: driver),
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
        const Text(
          'PRICE POSITION',
          style: TextStyle(
            color: AppColors.grey500,
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
                            AppColors.grey300, // Low price
                            AppColors.grey600, // Median
                            AppColors.grey800, // High price
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
                        color: est.rating.color.withAlpha(153),
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
                            color: est.rating.color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${(est.percentile * 100).round()}th',
                            style: const TextStyle(
                              color: AppColors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Icon(Icons.arrow_drop_down, color: est.rating.color, size: 16),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Lower', style: TextStyle(color: AppColors.grey600, fontSize: 10)),
            Text('Neighborhood Average', style: TextStyle(color: AppColors.grey600, fontSize: 10)),
            Text('Higher', style: TextStyle(color: AppColors.grey600, fontSize: 10)),
          ],
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Stat chip (Low / Median / High)
// ──────────────────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
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
              style: const TextStyle(
                color: AppColors.grey400,
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
}

// ──────────────────────────────────────────────────────────────────────────────
// Value driver row
// ──────────────────────────────────────────────────────────────────────────────

class _DriverRow extends StatelessWidget {
  const _DriverRow({required this.driver});

  final ValueDriver driver;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: driver.isPositive ? AppColors.grey800 : AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              driver.isPositive ? Icons.trending_up : Icons.trending_down,
              color: driver.isPositive ? AppColors.white : AppColors.grey500,
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
              color: driver.isPositive ? AppColors.white : AppColors.grey500,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
