import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/country_service.dart';

/// Verifies the current user's phone number via Firebase's SMS OTP flow,
/// then submits the resulting Firebase ID token to our backend
/// (POST /api/users/me/verify-phone), which independently confirms the
/// token's phone_number claim before marking the account verified.
///
/// This mirrors the existing Google sign-in pattern in AuthService:
/// Firebase does the identity work client-side, our backend re-verifies
/// the token server-side rather than trusting the client's word for it.
class PhoneVerificationPage extends StatefulWidget {
  const PhoneVerificationPage({super.key});

  @override
  State<PhoneVerificationPage> createState() => _PhoneVerificationPageState();
}

class _PhoneVerificationPageState extends State<PhoneVerificationPage> {
  static const Map<String, String> _dialCodes = {
    'KE': '+254',
    'IN': '+91',
    'NG': '+234',
    'US': '+1',
    'GB': '+44',
    'AE': '+971',
  };

  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  bool _codeSent = false;
  bool _isLoading = false;
  String? _verificationId;
  String? _error;

  String get _dialCode => _dialCodes[CountryService.config.code] ?? '+254';

  void _sendCode() async {
    final localNumber = _phoneCtrl.text.trim();
    if (localNumber.isEmpty) {
      setState(() => _error = 'Enter your phone number');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final fullNumber = '$_dialCode$localNumber';

    await fb_auth.FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: fullNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (fb_auth.PhoneAuthCredential credential) async {
        // Android auto-retrieval can complete verification without the
        // user typing a code at all -- if that happens, finish the flow
        // immediately instead of waiting for manual code entry.
        await _finishWithCredential(credential);
      },
      verificationFailed: (fb_auth.FirebaseAuthException e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _error = e.message ?? 'Could not send verification code. Please try again.';
        });
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _codeSent = true;
          _verificationId = verificationId;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  void _confirmCode() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty || _verificationId == null) {
      setState(() => _error = 'Enter the code sent to your phone');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final credential = fb_auth.PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: code,
    );

    await _finishWithCredential(credential);
  }

  Future<void> _finishWithCredential(fb_auth.PhoneAuthCredential credential) async {
    try {
      final userCredential = await fb_auth.FirebaseAuth.instance.signInWithCredential(credential);
      final idToken = await userCredential.user?.getIdToken();
      if (idToken == null) {
        throw Exception('Could not obtain a verification token.');
      }

      await ApiService.post('/api/users/me/verify-phone', {'idToken': idToken});

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Verification failed: $e';
      });
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Verify Phone Number', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _codeSent
                    ? 'Enter the 6-digit code sent to $_dialCode${_phoneCtrl.text.trim()}'
                    : 'Landlords must verify a phone number before publishing a listing.',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
              const SizedBox(height: 24),

              if (!_codeSent) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(_dialCode, style: const TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: '712 345 678',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          filled: true,
                          fillColor: const Color(0xFF1C1C1E),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '000000',
                    hintStyle: TextStyle(color: Colors.grey[700], letterSpacing: 8),
                    filled: true,
                    fillColor: const Color(0xFF1C1C1E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ],

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : (_codeSent ? _confirmCode : _sendCode),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : Text(_codeSent ? 'Confirm Code' : 'Send Code',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),

              if (_codeSent) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => setState(() {
                            _codeSent = false;
                            _codeCtrl.clear();
                            _error = null;
                          }),
                  child: Text('Use a different number', style: TextStyle(color: Colors.grey[500])),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
