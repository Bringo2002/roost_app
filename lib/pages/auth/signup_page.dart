import 'package:flutter/material.dart';
import 'package:roost_app/pages/onboarding/onboarding_page.dart';
import 'package:roost_app/pages/auth/login_page.dart';
import 'package:roost_app/services/auth_service.dart';
import 'package:roost_app/widgets/common/roost_logo_icon.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _role = 'TENANT';
  bool _isLoading = false;
  bool _obscurePassword = true;

  static const _goldAccent = Colors.white;

  void _signup() async {
    if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await AuthService.signup(
      _nameCtrl.text.trim(),
      _emailCtrl.text.trim(),
      _passwordCtrl.text,
      _role,
    );
    setState(() => _isLoading = false);

    if (result.success) {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingPage()),
        (route) => false,
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Signup failed. Please try again.'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w400),
      prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFF1C1C1E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _goldAccent, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              Row(
                children: [
                  const RoostLogoIcon(size: 42),
                  const SizedBox(width: 14),
                  const Text(
                    'ROOST',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              const Text(
                'Create\naccount.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Join Nairobi\'s premier verified rental network',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),

              const SizedBox(height: 32),

              // Role Selector Chips
              const Text('Account Type', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _role = 'TENANT'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _role == 'TENANT' ? _goldAccent.withValues(alpha: 0.15) : const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _role == 'TENANT' ? _goldAccent : Colors.grey[900]!,
                            width: _role == 'TENANT' ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.home_outlined, color: _role == 'TENANT' ? _goldAccent : Colors.grey[500], size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Tenant',
                              style: TextStyle(
                                color: _role == 'TENANT' ? Colors.white : Colors.grey[400],
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _role = 'LANDLORD'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _role == 'LANDLORD' ? _goldAccent.withValues(alpha: 0.15) : const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _role == 'LANDLORD' ? _goldAccent : Colors.grey[900]!,
                            width: _role == 'LANDLORD' ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.vpn_key_outlined, color: _role == 'LANDLORD' ? _goldAccent : Colors.grey[500], size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Landlord',
                              style: TextStyle(
                                color: _role == 'LANDLORD' ? Colors.white : Colors.grey[400],
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              TextField(
                controller: _nameCtrl,
                style: const TextStyle(color: Colors.white),
                textCapitalization: TextCapitalization.words,
                decoration: _inputDecoration('Full Name', Icons.person_outline),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _emailCtrl,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration('Email Address', Icons.email_outlined),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _passwordCtrl,
                style: const TextStyle(color: Colors.white),
                obscureText: _obscurePassword,
                decoration: _inputDecoration(
                  'Password',
                  Icons.lock_outline,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Colors.grey[500],
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _goldAccent,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.grey[850],
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Text(
                          'Create Account',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Already have an account? ", style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                    child: const Text(
                      'Log In',
                      style: TextStyle(color: _goldAccent, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}
