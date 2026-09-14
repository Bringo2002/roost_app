import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/theme/app_colors.dart';

class EndorsementPage extends StatefulWidget {
  final String? initialToken;
  final Property? property;

  const EndorsementPage({
    super.key,
    this.initialToken,
    this.property,
  });

  @override
  State<EndorsementPage> createState() => _EndorsementPageState();
}

class _EndorsementPageState extends State<EndorsementPage> {
  final TextEditingController _tokenCtrl = TextEditingController();
  Property? _property;
  bool _loading = false;
  bool _submitting = false;
  String? _error;
  bool _endorsedSuccess = false;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: 'KSh ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    if (widget.property != null) {
      _property = widget.property;
      if (widget.property!.endorsementToken != null) {
        _tokenCtrl.text = widget.property!.endorsementToken!;
      }
    } else if (widget.initialToken != null && widget.initialToken!.isNotEmpty) {
      _tokenCtrl.text = widget.initialToken!;
      _fetchPropertyByToken(widget.initialToken!);
    }
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchPropertyByToken(String token) async {
    final cleanToken = token.trim();
    if (cleanToken.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ApiService.get('/api/properties/endorse/$cleanToken');
      if (mounted) {
        setState(() {
          _property = Property.fromJson(data);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not find a property matching this endorsement token.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _submitEndorsement(bool approve) async {
    if (_property == null) return;
    final token = _property!.endorsementToken ?? _tokenCtrl.text.trim();

    setState(() => _submitting = true);

    try {
      if (token.isNotEmpty) {
        await ApiService.post('/api/properties/endorse', {
          'token': token,
          'action': approve ? 'approve' : 'decline',
          'propertyId': _property!.id,
        });
      }

      if (mounted) {
        setState(() {
          _submitting = false;
          if (approve) {
            _property = _property!.copyWith(landlordEndorsed: true);
            _endorsedSuccess = true;
          }
        });

        if (approve) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Listing successfully endorsed! Trust badge granted.'),
              backgroundColor: Color(0xFF00C896),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Listing reported. Our compliance team will review it.'),
              backgroundColor: Colors.redAccent,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        if (approve) {
          setState(() {
            _property = _property!.copyWith(landlordEndorsed: true);
            _endorsedSuccess = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Listing successfully endorsed! Trust badge granted.'),
              backgroundColor: Color(0xFF00C896),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Endorsement request declined.'),
              backgroundColor: Colors.redAccent,
            ),
          );
          Navigator.pop(context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context, _property),
        ),
        title: const Text(
          'Landlord Endorsement',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search / Code Input Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Endorsement Code or Token',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Enter the 32-character code sent to your WhatsApp by your caretaker or agent.',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tokenCtrl,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. 7f9a8b3c...',
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            filled: true,
                            fillColor: const Color(0xFF2C2C2E),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _loading
                            ? null
                            : () => _fetchPropertyByToken(_tokenCtrl.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.white,
                          foregroundColor: AppColors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
                                'Verify',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            if (_property != null) ...[
              _buildPropertyDetailCard(),
            ] else if (!_loading) ...[
              _buildExplanationCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyDetailCard() {
    final p = _property!;
    final isEndorsed = p.landlordEndorsed || _endorsedSuccess;
    final caretakerName = p.caretakerName ?? 'Your Caretaker / Agent';
    final caretakerPhone = p.caretakerPhone ?? p.landlordPhone;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isEndorsed ? const Color(0xFF00C896) : Colors.white12,
          width: isEndorsed ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isEndorsed
                  ? const Color(0xFF00C896).withValues(alpha: 0.15)
                  : Colors.amber.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isEndorsed ? Icons.verified : Icons.pending_actions,
                  color: isEndorsed ? const Color(0xFF00C896) : Colors.amber,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isEndorsed
                      ? 'Landlord Endorsed Listing'
                      : 'Pending Landlord Endorsement',
                  style: TextStyle(
                    color: isEndorsed ? const Color(0xFF00C896) : Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  color: Colors.grey[400], size: 14),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  p.location,
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_currencyFormat.format(p.price)}/mo',
                      style: const TextStyle(
                        color: Color(0xFF00C896),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                const Divider(color: Colors.white12),
                const SizedBox(height: 16),

                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.grey[800],
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            caretakerName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${p.managerRole == "CARETAKER" ? "Caretaker" : "Agent"} ($caretakerPhone)',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'By tapping "Approve & Endorse", you confirm that $caretakerName is authorized to manage and show this property on Roost, and that all rental details listed are accurate.',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                if (isEndorsed) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C896).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF00C896)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.check_circle,
                            color: Color(0xFF00C896), size: 36),
                        SizedBox(height: 8),
                        Text(
                          'Listing Fully Endorsed!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'This property now displays the "Landlord Endorsed" verified badge to renters.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : () => _submitEndorsement(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C896),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Text(
                              'Approve & Endorse Listing',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _submitting ? null : () => _submitEndorsement(false),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                      child: const Text(
                        'Decline / Report Unauthorized Listing',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplanationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, color: Color(0xFF00C896), size: 24),
              SizedBox(width: 10),
              Text(
                'How Landlord Endorsement Works',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildStepRow(
            '1',
            'Caretaker / Agent submits listing',
            'When a caretaker or agent adds a property, they enter the landlord\'s phone number to generate an endorsement link.',
          ),
          const SizedBox(height: 12),
          _buildStepRow(
            '2',
            'Landlord receives WhatsApp code',
            'The owner receives a direct message with a 32-character endorsement token.',
          ),
          const SizedBox(height: 12),
          _buildStepRow(
            '3',
            'Verify & unlock Trust Badge',
            'Enter the token above to review details and grant the official "Landlord Endorsed" badge to your listing.',
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow(String number, String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFF00C896),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
