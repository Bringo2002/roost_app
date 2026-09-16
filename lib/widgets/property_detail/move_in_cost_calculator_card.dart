import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/country_service.dart';
import 'package:roost_app/theme/app_colors.dart';

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

  void _copySummaryToClipboard() {
    final p = widget.property;
    final initialTotal = p.totalInitialMoveInCost;
    final symbol = CountryService.config.currencySymbol;

    final text = '''
🏠 Move-in Cost Breakdown for "${p.title}" (${p.location})
------------------------------------------------
• 1st Month Rent: $symbol ${_currencyFormat.format(p.price)}
• Security Deposit (${p.depositMonths} Month): $symbol ${_currencyFormat.format(p.price * p.depositMonths)}
• Water & Sewage: $symbol ${_currencyFormat.format(p.waterFee)}/mo
• Garbage Fee: $symbol ${_currencyFormat.format(p.garbageFee)}/mo
• Service Charge: $symbol ${_currencyFormat.format(p.serviceCharge)}/mo
• Electricity: ${p.electricityType.toUpperCase()}
------------------------------------------------
💰 TOTAL INITIAL MOVE-IN CAPITAL: $symbol ${_currencyFormat.format(initialTotal)}

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
    final rent = p.price;
    final deposit = rent * p.depositMonths;

    double displayTotal;
    if (_leaseDurationMonths == 1) {
      displayTotal = p.totalInitialMoveInCost;
    } else {
      // Total projected cost over N months = deposit + (monthly total * N)
      displayTotal = deposit + (p.totalMonthlyUtilityCost * _leaseDurationMonths);
    }

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
          // ── Header Title & Copy Button ────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.calculate_rounded, color: AppColors.white, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Move-in & Utility Calculator',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: AppColors.grey400, size: 18),
                onPressed: _copySummaryToClipboard,
                tooltip: 'Copy Breakdown',
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Duration Filter Segmented Pill ─────────────────────────────────
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                _buildSegmentTab(1, 'Initial Move-in'),
                _buildSegmentTab(6, '6 Months'),
                _buildSegmentTab(12, '1 Year'),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ── Big Total Capital Display Card ─────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1F1C2C), Color(0xFF2A2A36)],
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
                  _leaseDurationMonths == 1
                      ? 'TOTAL INITIAL MOVE-IN CAPITAL'
                      : 'PROJECTED $_leaseDurationMonths-MONTH TOTAL EXPENSE',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _formatCurrency(displayTotal),
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _leaseDurationMonths == 1 ? 'initial total' : 'over $_leaseDurationMonths months',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'ITEMIZED BREAKDOWN',
            style: TextStyle(
              color: AppColors.grey500,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),

          const SizedBox(height: 10),

          // ── Expense Table ──────────────────────────────────────────────────
          _buildExpenseRow(
            icon: Icons.home_rounded,
            iconColor: const Color(0xFF38BDF8),
            title: '1st Month Rent',
            subtitle: 'Base monthly rent',
            amount: _formatCurrency(rent * (_leaseDurationMonths == 1 ? 1 : _leaseDurationMonths)),
          ),
          const Divider(height: 1, color: AppColors.border),

          _buildExpenseRow(
            icon: Icons.lock_rounded,
            iconColor: Colors.amber,
            title: 'Refundable Security Deposit',
            subtitle: '${p.depositMonths} Month deposit held by owner',
            amount: _formatCurrency(deposit),
          ),
          const Divider(height: 1, color: AppColors.border),

          _buildExpenseRow(
            icon: Icons.water_drop_rounded,
            iconColor: Colors.blueAccent,
            title: 'Water & Sewage Fee',
            subtitle: 'Monthly water estimate',
            amount: _formatCurrency(p.waterFee * (_leaseDurationMonths == 1 ? 1 : _leaseDurationMonths)),
          ),
          const Divider(height: 1, color: AppColors.border),

          _buildExpenseRow(
            icon: Icons.delete_outline_rounded,
            iconColor: Colors.orangeAccent,
            title: 'Garbage Collection',
            subtitle: 'Sanitation & waste pickup',
            amount: _formatCurrency(p.garbageFee * (_leaseDurationMonths == 1 ? 1 : _leaseDurationMonths)),
          ),
          const Divider(height: 1, color: AppColors.border),

          _buildExpenseRow(
            icon: Icons.shield_outlined,
            iconColor: const Color(0xFF10B981),
            title: 'Service Charge',
            subtitle: 'Security, compound & common lighting',
            amount: _formatCurrency(p.serviceCharge * (_leaseDurationMonths == 1 ? 1 : _leaseDurationMonths)),
          ),
          const Divider(height: 1, color: AppColors.border),

          _buildExpenseRow(
            icon: Icons.bolt_rounded,
            iconColor: Colors.yellowAccent,
            title: 'Electricity Metering',
            subtitle: p.electricityType.toLowerCase() == 'tokens'
                ? 'Prepaid KPLC Tokens (Pay as you use)'
                : p.electricityType.toLowerCase() == 'included'
                    ? 'Included in rent'
                    : 'Postpaid Monthly Bill',
            amount: p.electricityType.toLowerCase() == 'included' ? 'INCLUDED' : 'TOKENS / USAGE',
          ),

          const SizedBox(height: 16),

          // ── Transparency Note ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined, color: Color(0xFF38BDF8), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No hidden admin or agency viewing fees. Rent paid directly to verified host.',
                    style: TextStyle(color: Colors.grey[400], fontSize: 11),
                  ),
                ),
              ],
            ),
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
    required Color iconColor,
    required String title,
    required String subtitle,
    required String amount,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
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
                  style: TextStyle(color: AppColors.grey400, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
