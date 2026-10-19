import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/country_service.dart';
import 'package:roost_app/theme/app_colors.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Design tokens
// ──────────────────────────────────────────────────────────────────────────────

const _kCardRadius = 22.0;
const _kIconContainerSize = 38.0;
const _kExpenseIconSize = 34.0;

/// Breaks down what a tenant actually needs saved up before signing --
/// rent, deposit, and recurring fees -- with a toggle between the
/// initial move-in number and a projected total over 6 or 12 months.
class MoveInCostCalculatorCard extends StatefulWidget {
  const MoveInCostCalculatorCard({super.key, required this.property});

  final Property property;

  @override
  State<MoveInCostCalculatorCard> createState() => _MoveInCostCalculatorCardState();
}

class _MoveInCostCalculatorCardState extends State<MoveInCostCalculatorCard> {
  int _leaseDurationMonths = 1; // 1 = initial move-in, 6, 12

  static final _currencyFormat = NumberFormat('#,##0', 'en_US');

  String _formatCurrency(double amount) {
    final symbol = CountryService.config.currencySymbol;
    return '$symbol ${_currencyFormat.format(amount)}';
  }

  /// Returns formatted currency (scaled by the selected duration) if
  /// amount > 0, otherwise 'Not specified'.
  String _formatOrNotSpecified(double amount) {
    if (amount <= 0) return 'Not specified';
    return _formatCurrency(amount * _leaseDurationMonths);
  }

  String get _rentRowTitle => _leaseDurationMonths == 1 ? "1st Month's Rent" : "$_leaseDurationMonths Months' Rent";

  double get _displayTotal {
    final p = widget.property;
    if (_leaseDurationMonths == 1) return p.totalInitialMoveInCost;
    // Deposit is paid once; rent and recurring utility costs scale
    // with the selected duration. Note: totalMonthlyUtilityCost
    // already includes base rent — see Property model.
    return (p.price * p.depositMonths) +
        (p.totalMonthlyUtilityCost * _leaseDurationMonths);
  }

  void _copySummaryToClipboard() {
    final p = widget.property;
    final symbol = CountryService.config.currencySymbol;
    final rentLabel = _leaseDurationMonths == 1 ? '1st Month Rent' : '$_leaseDurationMonths Months\' Rent';
    final rentAmount = p.price * _leaseDurationMonths;

    final text = '''
🏠 Move-in Cost Breakdown for "${p.title}" (${p.location})
------------------------------------------------
• $rentLabel: $symbol ${_currencyFormat.format(rentAmount)}
• Security Deposit (${p.depositMonths} Month, one-time): $symbol ${_currencyFormat.format(p.price * p.depositMonths)}
• Water & Sewage: ${_formatOrNotSpecified(p.waterFee)}
• Garbage Fee: ${_formatOrNotSpecified(p.garbageFee)}
• Service Charge: ${_formatOrNotSpecified(p.serviceCharge)}
• Electricity: ${p.electricityType.toUpperCase()} (billed separately, not included below)
------------------------------------------------
💰 ${_leaseDurationMonths == 1 ? 'TOTAL INITIAL MOVE-IN CAPITAL' : 'PROJECTED $_leaseDurationMonths-MONTH TOTAL'}: $symbol ${_currencyFormat.format(_displayTotal)}

Calculated via Roost App 📱
''';

    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Expense summary copied to clipboard! Ready to share.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.property;
    final deposit = p.price * p.depositMonths;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
            child: Row(
              children: [
                // Tinted icon container
                Container(
                  width: _kIconContainerSize,
                  height: _kIconContainerSize,
                  decoration: BoxDecoration(
                    color: AppColors.white.withAlpha(12),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white.withAlpha(25)),
                  ),
                  child: const Icon(
                    Icons.calculate_rounded,
                    color: AppColors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Move-in calculator',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Rent, deposit & recurring fees',
                        style: TextStyle(
                          color: AppColors.grey500,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                // Copy button with subtle background
                Material(
                  color: AppColors.grey800,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: _copySummaryToClipboard,
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.copy_rounded, color: AppColors.grey300, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Duration selector ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  _DurationTab(
                    label: 'Move-in',
                    isSelected: _leaseDurationMonths == 1,
                    onTap: () => setState(() => _leaseDurationMonths = 1),
                  ),
                  _DurationTab(
                    label: '6 months',
                    isSelected: _leaseDurationMonths == 6,
                    onTap: () => setState(() => _leaseDurationMonths = 6),
                  ),
                  _DurationTab(
                    label: '1 year',
                    isSelected: _leaseDurationMonths == 12,
                    onTap: () => setState(() => _leaseDurationMonths = 12),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          // ── Animated content ────────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: Padding(
              key: ValueKey(_leaseDurationMonths),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Total panel ─────────────────────────────────────
                  _TotalPanel(
                    label: _leaseDurationMonths == 1
                        ? 'Total initial move-in capital'
                        : 'Projected $_leaseDurationMonths-month total',
                    amount: _displayTotal,
                    suffix: _leaseDurationMonths == 1
                        ? 'initial total'
                        : 'over $_leaseDurationMonths months',
                    formatCurrency: _formatCurrency,
                  ),

                  const SizedBox(height: 20),

                  // ── Section header ──────────────────────────────────
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.grey500,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'ITEMIZED BREAKDOWN',
                        style: TextStyle(
                          color: AppColors.grey500,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Line items ──────────────────────────────────────
                  _ExpenseRow(
                    icon: Icons.home_rounded,
                    title: _rentRowTitle,
                    subtitle: 'Base monthly rent',
                    amount: _formatCurrency(p.price * _leaseDurationMonths),
                  ),

                  _ExpenseRow(
                    icon: Icons.lock_rounded,
                    title: 'Security deposit',
                    subtitle: '${p.depositMonths}mo deposit · one-time · refundable',
                    amount: _formatCurrency(deposit),
                  ),

                  _ExpenseRow(
                    icon: Icons.water_drop_rounded,
                    title: 'Water & sewage',
                    subtitle: 'Monthly estimate',
                    amount: _formatOrNotSpecified(p.waterFee),
                    isDimmed: p.waterFee <= 0,
                  ),

                  _ExpenseRow(
                    icon: Icons.delete_outline_rounded,
                    title: 'Garbage collection',
                    subtitle: 'Sanitation & waste pickup',
                    amount: _formatOrNotSpecified(p.garbageFee),
                    isDimmed: p.garbageFee <= 0,
                  ),

                  _ExpenseRow(
                    icon: Icons.shield_outlined,
                    title: 'Service charge',
                    subtitle: 'Security & common lighting',
                    amount: _formatOrNotSpecified(p.serviceCharge),
                    isDimmed: p.serviceCharge <= 0,
                  ),

                  _ExpenseRow(
                    icon: Icons.bolt_rounded,
                    title: 'Electricity',
                    subtitle: _electricitySubtitle(p.electricityType),
                    amount: _electricityAmount(p.electricityType),
                    isDimmed: p.electricityType.toLowerCase() != 'included',
                    isLast: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _electricitySubtitle(String type) => switch (type.toLowerCase()) {
        'tokens' => 'Prepaid tokens · not in total',
        'included' => 'Included in rent',
        _ => 'Postpaid bill · not in total',
      };

  static String _electricityAmount(String type) => switch (type.toLowerCase()) {
        'included' => 'Included',
        _ => 'Usage-based',
      };
}

// ──────────────────────────────────────────────────────────────────────────────
// Duration tab
// ──────────────────────────────────────────────────────────────────────────────

class _DurationTab extends StatelessWidget {
  const _DurationTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? AppColors.black : AppColors.grey400,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Total panel
// ──────────────────────────────────────────────────────────────────────────────

class _TotalPanel extends StatelessWidget {
  const _TotalPanel({
    required this.label,
    required this.amount,
    required this.suffix,
    required this.formatCurrency,
  });

  final String label;
  final double amount;
  final String suffix;
  final String Function(double) formatCurrency;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.white.withAlpha(10),
            AppColors.white.withAlpha(4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.grey400,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // The figure animates toward the total on screen; a screen reader
          // gets the final amount once instead of every in-between value.
          Semantics(
            container: true,
            excludeSemantics: true,
            label: formatCurrency(amount),
            child: TweenAnimationBuilder<double>(
              key: ValueKey(amount),
              tween: Tween(begin: amount * 0.8, end: amount),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, val, _) => Text(
                formatCurrency(val),
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            suffix,
            style: const TextStyle(color: AppColors.grey500, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.grey800.withAlpha(150),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, color: AppColors.grey500, size: 11),
                SizedBox(width: 5),
                Text(
                  'Excludes electricity (usage-based)',
                  style: TextStyle(
                    color: AppColors.grey500,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Expense row
// ──────────────────────────────────────────────────────────────────────────────

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.isDimmed = false,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String amount;
  final bool isDimmed;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              // Icon container — dimmed items get a lighter treatment
              Container(
                width: _kExpenseIconSize,
                height: _kExpenseIconSize,
                decoration: BoxDecoration(
                  color: isDimmed
                      ? AppColors.grey800.withAlpha(120)
                      : AppColors.grey800,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isDimmed ? AppColors.grey600 : AppColors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDimmed
                            ? AppColors.grey500
                            : AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDimmed ? AppColors.grey600 : AppColors.grey400,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Amount — "Not specified" gets a muted pill style
              if (isDimmed && amount == 'Not specified')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.grey800.withAlpha(120),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    amount,
                    style: const TextStyle(
                      color: AppColors.grey600,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              else
                Flexible(
                  flex: 0,
                  child: Text(
                    amount,
                    style: TextStyle(
                      color: isDimmed ? AppColors.grey500 : AppColors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            color: AppColors.grey800.withAlpha(120),
            indent: _kExpenseIconSize + 12,
          ),
      ],
    );
  }
}
