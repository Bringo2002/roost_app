import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roost_app/pages/search/location_picker_page.dart';
import 'package:roost_app/services/api_service.dart';

class AddPropertyPage extends StatefulWidget {
  const AddPropertyPage({super.key});

  @override
  State<AddPropertyPage> createState() => _AddPropertyPageState();
}

class _AddPropertyPageState extends State<AddPropertyPage> {
  int _step = 0;
  bool _isLoading = false;

  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _depositCtrl = TextEditingController();
  final _bedroomsCtrl = TextEditingController(text: '1');
  final _bathroomsCtrl = TextEditingController(text: '1');
  final _descriptionCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _imageUrlCtrl = TextEditingController();
  final _galleryUrlCtrl = TextEditingController();

  String _houseType = '1BR';
  String _moveInDate = 'Immediate';
  double? _latitude = -1.2921;
  double? _longitude = 36.8219;

  bool _furnished = false;
  bool _parking = false;
  bool _wifi = false;
  bool _water = true;
  bool _security = true;
  bool _balcony = false;
  bool _petFriendly = false;

  final List<String> _imageUrls = [];

  Future<void> _pickLocation() async {
    final latlng = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerPage()),
    );
    if (latlng != null) {
      setState(() {
        _latitude = latlng.latitude;
        _longitude = latlng.longitude;
      });
    }
  }

  Future<void> _submitProperty() async {
    if (_titleCtrl.text.isEmpty || _priceCtrl.text.isEmpty || _locationCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final primaryImage = _imageUrlCtrl.text.trim().isNotEmpty
          ? _imageUrlCtrl.text.trim()
          : (_imageUrls.isNotEmpty ? _imageUrls.first : 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800');

      await ApiService.post('/api/properties', {
        'title': _titleCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'price': double.tryParse(_priceCtrl.text.trim()) ?? 0.0,
        'deposit': _depositCtrl.text.trim(),
        'bedrooms': int.tryParse(_bedroomsCtrl.text.trim()) ?? 1,
        'bathrooms': int.tryParse(_bathroomsCtrl.text.trim()) ?? 1,
        'houseType': _houseType,
        'type': 'RENTAL',
        'available': true,
        'verified': true,
        'landlordPhone': _phoneCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'imageUrl': primaryImage,
        'imageUrls': _imageUrls,
        'latitude': _latitude,
        'longitude': _longitude,
        'furnished': _furnished,
        'parking': _parking,
        'wifi': _wifi,
        'water': _water,
        'security': _security,
        'balcony': _balcony,
        'petFriendly': _petFriendly,
        'moveInDate': _moveInDate,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Property listed successfully!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to publish listing: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _nextStep() {
    if (_step < 4) {
      setState(() => _step++);
    } else {
      _submitProperty();
    }
  }

  void _prevStep() {
    if (_step > 0) {
      setState(() => _step--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('List a Property', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C853)))
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Step Progress Indicator
                    Row(
                      children: List.generate(
                        5,
                        (idx) => Expanded(
                          child: Container(
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: idx <= _step ? const Color(0xFF00C853) : const Color(0xFF1C1C1E),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Expanded(
                      child: SingleChildScrollView(
                        child: _buildStepContent(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        if (_step > 0)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _prevStep,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Color(0xFF2C2C2E)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Back'),
                            ),
                          ),
                        if (_step > 0) const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _nextStep,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00C853),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              _step == 4 ? 'Publish Listing' : 'Next Step',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Property Photos', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Add high quality photos to attract renters', style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 20),
            TextField(
              controller: _imageUrlCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Primary Photo Image URL'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _galleryUrlCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Gallery Photo URL'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    final url = _galleryUrlCtrl.text.trim();
                    if (url.isNotEmpty) {
                      setState(() {
                        _imageUrls.add(url);
                        _galleryUrlCtrl.clear();
                      });
                    }
                  },
                  icon: const Icon(Icons.add_circle, color: Color(0xFF00C853), size: 36),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_imageUrls.isNotEmpty)
              Wrap(
                spacing: 8,
                children: _imageUrls.map((url) {
                  return Chip(
                    backgroundColor: const Color(0xFF1C1C1E),
                    label: Text(url.length > 20 ? '${url.substring(0, 20)}...' : url, style: const TextStyle(color: Colors.white)),
                    deleteIcon: const Icon(Icons.close, color: Colors.grey, size: 14),
                    onDeleted: () => setState(() => _imageUrls.remove(url)),
                  );
                }).toList(),
              ),
          ],
        );

      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Basic Information', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Title, house type, rent, and bedrooms', style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 20),
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Listing Title (e.g. Modern 2BR Kilimani)'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _houseType,
              dropdownColor: const Color(0xFF1C1C1E),
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('House Type'),
              items: ['BEDSITTER', 'STUDIO', '1BR', '2BR', '3BR+'].map((t) {
                return DropdownMenuItem(value: t, child: Text(t));
              }).toList(),
              onChanged: (val) => setState(() => _houseType = val!),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Monthly Rent (KES)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _depositCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Deposit Terms'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _bedroomsCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Bedrooms'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _bathroomsCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Bathrooms'),
                  ),
                ),
              ],
            ),
          ],
        );

      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Location', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Specify district & precise GPS location', style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 20),
            TextField(
              controller: _locationCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Location (e.g. Kilimani, Chania Avenue)'),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _pickLocation,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF2C2C2E)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.my_location, color: Color(0xFF00C853)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _latitude != null ? 'Coordinates: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}' : 'Tap to pin on Map',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ],
        );

      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Amenities & Features', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Select features available at this property', style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 20),
            CheckboxListTile(
              title: const Text('Furnished', style: TextStyle(color: Colors.white)),
              value: _furnished,
              activeColor: const Color(0xFF00C853),
              onChanged: (val) => setState(() => _furnished = val!),
            ),
            CheckboxListTile(
              title: const Text('Parking Available', style: TextStyle(color: Colors.white)),
              value: _parking,
              activeColor: const Color(0xFF00C853),
              onChanged: (val) => setState(() => _parking = val!),
            ),
            CheckboxListTile(
              title: const Text('WiFi Internet', style: TextStyle(color: Colors.white)),
              value: _wifi,
              activeColor: const Color(0xFF00C853),
              onChanged: (val) => setState(() => _wifi = val!),
            ),
            CheckboxListTile(
              title: const Text('24hr Water Supply', style: TextStyle(color: Colors.white)),
              value: _water,
              activeColor: const Color(0xFF00C853),
              onChanged: (val) => setState(() => _water = val!),
            ),
            CheckboxListTile(
              title: const Text('Security Guard / CCTV', style: TextStyle(color: Colors.white)),
              value: _security,
              activeColor: const Color(0xFF00C853),
              onChanged: (val) => setState(() => _security = val!),
            ),
            CheckboxListTile(
              title: const Text('Balcony View', style: TextStyle(color: Colors.white)),
              value: _balcony,
              activeColor: const Color(0xFF00C853),
              onChanged: (val) => setState(() => _balcony = val!),
            ),
            CheckboxListTile(
              title: const Text('Pet Friendly', style: TextStyle(color: Colors.white)),
              value: _petFriendly,
              activeColor: const Color(0xFF00C853),
              onChanged: (val) => setState(() => _petFriendly = val!),
            ),
          ],
        );

      case 4:
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Description & Contact', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Add property details and direct contact phone', style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 20),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Contact Phone (e.g. +254 712 345 678)'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionCtrl,
              maxLines: 4,
              maxLength: 500,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Description (max 500 chars)'),
            ),
          ],
        );
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[500]),
      filled: true,
      fillColor: const Color(0xFF1C1C1E),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }
}
