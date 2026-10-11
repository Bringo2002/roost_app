import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/country_service.dart';
import 'package:roost_app/theme/app_colors.dart';

/// Breaks down what a tenant actually needs saved up before signing --
/// rent, deposit, and recurring fees -- with a toggle between the
/// initial move-in number and a projected total over 6 or 12 months.
///
/// Monochrome throughout: the total-cost panel uses a subtle grayscale
/// gradient (AppColors.black -> grey900) for visual depth rather than
/// a flat fill, and every itemized row's icon sits in a plain grey800
/// circle -- no accent colors, matching the rest of the app.
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

  /// Builds the same figures the card is currently displaying --
  /// sharing this with the on-screen build means the copied summary
  /// can never drift from what the tenant is actually looking at,
  /// regardless of which duration tab is selected.
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.calculate_rounded, color: AppColors.white, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Move-in & utility calculator',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: AppColors.grey400, size: 18),
                onPressed: _copySummaryToClipboard,
                tooltip: 'Copy breakdown',
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Duration selector ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                _DurationTab(
                  label: 'Initial move-in',
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

          const SizedBox(height: 18),

          // ── Animated content ────────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: Column(
              key: ValueKey(_leaseDurationMonths),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Total panel ───────────────────────────────────────
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

                // ── Itemized breakdown ────────────────────────────────
                const Text(
                  'Itemized breakdown',
                  style: TextStyle(
                    color: AppColors.grey400,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                _ExpenseRow(
                  icon: Icons.home_rounded,
                  title: _rentRowTitle,
                  subtitle: 'Base monthly rent',
                  amount: _formatCurrency(p.price * _leaseDurationMonths),
                ),
                const Divider(height: 1, color: AppColors.border),

                _ExpenseRow(
                  icon: Icons.lock_rounded,
                  title: 'Refundable security deposit',
                  subtitle: '${p.depositMonths} month deposit, paid once, held by owner',
                  amount: _formatCurrency(deposit),
                ),
                const Divider(height: 1, color: AppColors.border),

                _ExpenseRow(
                  icon: Icons.water_drop_rounded,
                  title: 'Water & sewage fee',
                  subtitle: 'Monthly water estimate',
                  amount: _formatOrNotSpecified(p.waterFee),
                ),
                const Divider(height: 1, color: AppColors.border),

                _ExpenseRow(
                  icon: Icons.delete_outline_rounded,
                  title: 'Garbage collection',
                  subtitle: 'Sanitation & waste pickup',
                  amount: _formatOrNotSpecified(p.garbageFee),
                ),
                const Divider(height: 1, color: AppColors.border),

                _ExpenseRow(
                  icon: Icons.shield_outlined,
                  title: 'Service charge',
                  subtitle: 'Security, compound & common lighting',
                  amount: _formatOrNotSpecified(p.serviceCharge),
                ),
                const Divider(height: 1, color: AppColors.border),

                _ExpenseRow(
                  icon: Icons.bolt_rounded,
                  title: 'Electricity metering',
                  subtitle: _electricitySubtitle(p.electricityType),
                  amount: _electricityAmount(p.electricityType),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _electricitySubtitle(String type) => switch (type.toLowerCase()) {
        'tokens' => 'Prepaid KPLC tokens (pay as you use) -- not in total above',
        'included' => 'Included in rent',
        _ => 'Postpaid monthly bill -- not in total above',
      };

  static String _electricityAmount(String type) => switch (type.toLowerCase()) {
        'included' => 'Included',
        _ => 'Usage-based',
      };
}

// ──────────────────────────────────────────────────────────────────────────────
// Duration tab
// ──────────────────────────────────────────────────────────────────────────────

/// One segment of the duration selector strip. Extracted from inline
/// `_buildSegmentTab` method so each tab is an isolated widget subtree.
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
        color: isSelected ? AppColors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? AppColors.black : AppColors.grey400,
                fontSize: 12,
                fontWeight: FontWeight.bold,
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

/// The hero number at the top of the calculator. Separated so the
/// TweenAnimationBuilder and its key logic stay contained.
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.black, AppColors.grey900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.grey400,
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            children: [
              TweenAnimationBuilder<double>(
                key: ValueKey(amount),
                tween: Tween(begin: amount * 0.8, end: amount),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (context, val, _) => Text(
                  formatCurrency(val),
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  suffix,
                  style: const TextStyle(color: AppColors.grey400, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '* Excludes electricity, billed separately based on usage',
            style: TextStyle(
              color: AppColors.grey500,
              fontSize: 10.5,
              fontStyle: FontStyle.italic,
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

/// A single line-item in the itemized breakdown. Extracted from the inline
/// `_buildExpenseRow` method so each row is a proper widget with its own
/// element in the tree (better rebuild isolation, profiling, and testing).
class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: AppColors.grey800,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.grey400,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 0,
            child: Text(
              amount,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
