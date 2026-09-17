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

  final _currencyFormat = NumberFormat('#,##0', 'en_US');

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
    // Deposit is paid once regardless of lease length; only the
    // recurring monthly costs scale with the selected duration.
    return (p.price * p.depositMonths) + (p.totalMonthlyUtilityCost * _leaseDurationMonths);
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.calculate_rounded, color: AppColors.white, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Move-in & utility calculator',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: AppColors.grey400, size: 18),
                onPressed: _copySummaryToClipboard,
                tooltip: 'Copy breakdown',
              ),
            ],
          ),

          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                _buildSegmentTab(1, 'Initial move-in'),
                _buildSegmentTab(6, '6 months'),
                _buildSegmentTab(12, '1 year'),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Total panel -- a subtle grayscale gradient (black to
          // grey900) for depth, no color, unlike the purple/blue
          // gradient this card used to have.
          Container(
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
                  _leaseDurationMonths == 1 ? 'Total initial move-in capital' : 'Projected $_leaseDurationMonths-month total',
                  style: const TextStyle(color: AppColors.grey400, fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _formatCurrency(_displayTotal),
                      style: const TextStyle(color: AppColors.white, fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _leaseDurationMonths == 1 ? 'initial total' : 'over $_leaseDurationMonths months',
                      style: const TextStyle(color: AppColors.grey400, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  '* Excludes electricity, billed separately based on usage',
                  style: TextStyle(color: AppColors.grey500, fontSize: 10.5, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'Itemized breakdown',
            style: TextStyle(color: AppColors.grey400, fontSize: 12, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          _buildExpenseRow(
            icon: Icons.home_rounded,
            title: _rentRowTitle,
            subtitle: 'Base monthly rent',
            amount: _formatCurrency(p.price * _leaseDurationMonths),
          ),
          const Divider(height: 1, color: AppColors.border),

          _buildExpenseRow(
            icon: Icons.lock_rounded,
            title: 'Refundable security deposit',
            subtitle: '${p.depositMonths} month deposit, paid once, held by owner',
            amount: _formatCurrency(deposit),
          ),
          const Divider(height: 1, color: AppColors.border),

          _buildExpenseRow(
            icon: Icons.water_drop_rounded,
            title: 'Water & sewage fee',
            subtitle: 'Monthly water estimate',
            amount: _formatOrNotSpecified(p.waterFee),
          ),
          const Divider(height: 1, color: AppColors.border),

          _buildExpenseRow(
            icon: Icons.delete_outline_rounded,
            title: 'Garbage collection',
            subtitle: 'Sanitation & waste pickup',
            amount: _formatOrNotSpecified(p.garbageFee),
          ),
          const Divider(height: 1, color: AppColors.border),

          _buildExpenseRow(
            icon: Icons.shield_outlined,
            title: 'Service charge',
            subtitle: 'Security, compound & common lighting',
            amount: _formatOrNotSpecified(p.serviceCharge),
          ),
          const Divider(height: 1, color: AppColors.border),

          _buildExpenseRow(
            icon: Icons.bolt_rounded,
            title: 'Electricity metering',
            subtitle: p.electricityType.toLowerCase() == 'tokens'
                ? 'Prepaid KPLC tokens (pay as you use) -- not in total above'
                : p.electricityType.toLowerCase() == 'included'
                    ? 'Included in rent'
                    : 'Postpaid monthly bill -- not in total above',
            amount: p.electricityType.toLowerCase() == 'included' ? 'Included' : 'Usage-based',
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentTab(int duration, String label) {
    final isSelected = _leaseDurationMonths == duration;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _leaseDurationMonths = duration),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
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
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String amount,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(color: AppColors.grey800, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: AppColors.grey400, fontSize: 11)),
              ],
            ),
          ),
          Text(amount, style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
