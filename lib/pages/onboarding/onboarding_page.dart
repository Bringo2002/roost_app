import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:roost_app/main.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _step = 0;

  String _houseType = 'Any';
  String _budget = 'KES 20k – 35k';
  String _moveInTimeframe = 'This Month';

  final List<String> _houseTypes = [
    'Bedsitter',
    'Studio',
    '1 Bedroom',
    '2 Bedroom',
    '3 Bedroom+',
    'Any',
  ];

  final List<String> _budgets = [
    'Under KES 10,000',
    'KES 10k – 20k',
    'KES 20k – 35k',
    'KES 35k – 50k',
    'KES 50k+',
  ];

  final List<String> _timeframes = [
    'Today',
    'This Week',
    'This Month',
    'Just Browsing',
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pref_house_type', _houseType);
    await prefs.setString('pref_budget', _budget);
    await prefs.setString('pref_timeframe', _moveInTimeframe);
    await prefs.setBool('onboarding_completed', true);

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  void _nextStep() {
    if (_step < 2) {
      setState(() => _step++);
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _completeOnboarding,
            child: const Text('Skip', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  3,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: index == _step ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: index == _step ? const Color(0xFF00C853) : const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              if (_step == 0) ...[
                const Text(
                  'What are you looking for?',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Select your preferred house type', style: TextStyle(color: Colors.grey[500])),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    children: _houseTypes.map((type) {
                      final selected = _houseType == type;
                      return GestureDetector(
                        onTap: () => setState(() => _houseType = type),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected ? const Color(0xFF00C853) : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(type, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                              const Spacer(),
                              if (selected)
                                const Icon(Icons.check_circle, color: Color(0xFF00C853)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ] else if (_step == 1) ...[
                const Text(
                  "What's your budget?",
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Select your monthly rent target', style: TextStyle(color: Colors.grey[500])),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    children: _budgets.map((b) {
                      final selected = _budget == b;
                      return GestureDetector(
                        onTap: () => setState(() => _budget = b),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected ? const Color(0xFF00C853) : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(b, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                              const Spacer(),
                              if (selected)
                                const Icon(Icons.check_circle, color: Color(0xFF00C853)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ] else ...[
                const Text(
                  'When do you need to move?',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('We will prioritize fresh listings', style: TextStyle(color: Colors.grey[500])),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    children: _timeframes.map((tf) {
                      final selected = _moveInTimeframe == tf;
                      return GestureDetector(
                        onTap: () => setState(() => _moveInTimeframe = tf),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected ? const Color(0xFF00C853) : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(tf, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                              const Spacer(),
                              if (selected)
                                const Icon(Icons.check_circle, color: Color(0xFF00C853)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C853),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    _step == 2 ? 'Get Started' : 'Continue',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
