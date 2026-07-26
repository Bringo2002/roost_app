import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/pages/search/location_picker_page.dart';
import 'package:roost_app/services/api_service.dart';

import 'package:roost_app/services/country_service.dart';

class AddPropertyPage extends StatefulWidget {
  const AddPropertyPage({super.key, this.editingProperty});

  /// When set, the page opens pre-filled with this listing's data and
  /// submits as an update (PUT) instead of creating a new listing.
  final Property? editingProperty;

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

  String _houseType = '1BR';
  final String _moveInDate = 'Immediate';
  double? _latitude;
  double? _longitude;
  bool _locationConfirmed = false;

  bool _furnished = false;
  bool _parking = false;
  bool _wifi = false;
  bool _water = true;
  bool _security = true;
  bool _balcony = false;
  bool _petFriendly = false;

  static const int _minPhotos = 3;
  static const int _maxPhotos = 10;
  final List<String> _imageUrls = [];
  final ImagePicker _picker = ImagePicker();
  bool _uploadingPhotos = false;
  int _uploadDone = 0;
  int _uploadTotal = 0;

  bool get _isEditing => widget.editingProperty != null;

  @override
  void initState() {
    super.initState();
    final p = widget.editingProperty;
    if (p == null) return;

    _titleCtrl.text = p.title;
    _locationCtrl.text = p.location;
    _priceCtrl.text = p.price == p.price.roundToDouble() ? p.price.toInt().toString() : p.price.toString();
    _depositCtrl.text = p.deposit ?? '';
    _bedroomsCtrl.text = p.bedrooms.toString();
    _bathroomsCtrl.text = p.bathrooms.toString();
    _descriptionCtrl.text = p.description;
    _phoneCtrl.text = p.landlordPhone;

    _houseType = p.houseType;
    if (p.latitude != null && p.longitude != null) {
      _latitude = p.latitude;
      _longitude = p.longitude;
      _locationConfirmed = true;
    }

    _furnished = p.furnished;
    _parking = p.parking;
    _wifi = p.wifi;
    _water = p.water;
    _security = p.security;
    _balcony = p.balcony;
    _petFriendly = p.petFriendly;

    _imageUrls.addAll(p.imageUrls);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _priceCtrl.dispose();
    _depositCtrl.dispose();
    _bedroomsCtrl.dispose();
    _bathroomsCtrl.dispose();
    _descriptionCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final latlng = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerPage()),
    );
    if (latlng != null) {
      setState(() {
        _latitude = latlng.latitude;
        _longitude = latlng.longitude;
        _locationConfirmed = true;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final remaining = _maxPhotos - _imageUrls.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maximum $_maxPhotos photos per listing')),
      );
      return;
    }
    // Compress/downscale at pick time rather than adding a separate
    // image-processing dependency -- keeps uploads fast on mobile data.
    final files = await _picker.pickMultiImage(imageQuality: 75, maxWidth: 1600);
    if (files.isEmpty) return;

    final toUpload = files.take(remaining).toList();
    if (files.length > remaining && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Only added $remaining -- maximum $_maxPhotos photos per listing')),
      );
    }
    await _uploadPhotos(toUpload);
  }

  Future<void> _takePhoto() async {
    if (_imageUrls.length >= _maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maximum $_maxPhotos photos per listing')),
      );
      return;
    }
    final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 75, maxWidth: 1600);
    if (file == null) return;
    await _uploadPhotos([file]);
  }

  /// Uploads sequentially rather than in parallel -- simpler progress
  /// tracking and more reliable on the mobile data connections most
  /// landlords will actually be using.
  Future<void> _uploadPhotos(List<XFile> files) async {
    setState(() {
      _uploadingPhotos = true;
      _uploadDone = 0;
      _uploadTotal = files.length;
    });

    for (final file in files) {
      try {
        final bytes = await file.readAsBytes();
        final result = await ApiService.post('/api/properties/upload-photo', {
          'data': base64Encode(bytes),
        });
        final url = result is Map ? result['url'] as String? : null;
        if (url != null && mounted) {
          setState(() => _imageUrls.add(url));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('A photo failed to upload: $e')),
          );
        }
      }
      if (mounted) setState(() => _uploadDone++);
    }

    if (mounted) setState(() => _uploadingPhotos = false);
  }

  void _removePhoto(String url) {
    setState(() => _imageUrls.remove(url));
  }

  Future<void> _submitProperty() async {
    if (_titleCtrl.text.isEmpty || _priceCtrl.text.isEmpty || _locationCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields.')),
      );
      return;
    }

    if (_imageUrls.length < _minPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Add at least $_minPhotos photos before publishing.')),
      );
      return;
    }

    if (!_locationConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pin the exact location on the map before publishing.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final payload = {
      'title': _titleCtrl.text.trim(),
      'location': _locationCtrl.text.trim(),
      'price': double.tryParse(_priceCtrl.text.trim()) ?? 0.0,
      'deposit': _depositCtrl.text.trim(),
      'bedrooms': int.tryParse(_bedroomsCtrl.text.trim()) ?? 1,
      'bathrooms': int.tryParse(_bathroomsCtrl.text.trim()) ?? 1,
      'houseType': _houseType,
      'type': 'RENTAL',
      // Editing preserves whatever the listing's current available/verified
      // status already is -- an edit shouldn't silently re-publish a
      // listing the landlord marked as rented, or un-verify one that
      // passed verification, just because they fixed a typo.
      'available': _isEditing ? widget.editingProperty!.available : true,
      'verified': _isEditing ? widget.editingProperty!.verified : false,
      'landlordPhone': _phoneCtrl.text.trim(),
      'description': _descriptionCtrl.text.trim(),
      'imageUrl': _imageUrls.first,
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
      'country': CountryService.config.code,
    };

    try {
      if (_isEditing) {
        await ApiService.put('/api/properties/${widget.editingProperty!.id}', payload);
      } else {
        await ApiService.post('/api/properties', payload);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? 'Listing updated' : 'Property listed successfully!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to ${_isEditing ? 'update' : 'publish'} listing: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _nextStep() {
    if (_step == 0 && _imageUrls.length < _minPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Add at least $_minPhotos photos to continue.')),
      );
      return;
    }
    if (_step == 2 && !_locationConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pin the exact location on the map to continue.')),
      );
      return;
    }
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
        title: Text(_isEditing ? 'Edit Listing' : 'List a Property', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
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
                              color: idx <= _step ? Colors.white : const Color(0xFF1C1C1E),
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
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              _step == 4 ? (_isEditing ? 'Save Changes' : 'Publish Listing') : 'Next Step',
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
            const SizedBox(height: 8),
            Text(
              _imageUrls.length >= _minPhotos
                  ? '${_imageUrls.length} of $_minPhotos minimum photos added'
                  : '${_imageUrls.length} of $_minPhotos minimum photos added -- add ${_minPhotos - _imageUrls.length} more',
              style: TextStyle(
                color: _imageUrls.length >= _minPhotos ? Colors.greenAccent : Colors.amber,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _uploadingPhotos ? null : _takePhoto,
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Take Photo'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF3A3A3C)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _uploadingPhotos ? null : _pickFromGallery,
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Gallery'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF3A3A3C)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            if (_uploadingPhotos) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Text('Uploading $_uploadDone of $_uploadTotal...', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                ],
              ),
            ],
            if (_imageUrls.isNotEmpty) ...[
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _imageUrls.length,
                itemBuilder: (context, index) {
                  final url = _imageUrls[index];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFF1C1C1E),
                            child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                          ),
                        ),
                      ),
                      if (index == 0)
                        Positioned(
                          left: 4,
                          top: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(6)),
                            child: const Text('Cover', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: GestureDetector(
                          onTap: () => _removePhoto(url),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
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
              initialValue: _houseType,
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
                    decoration: _inputDecoration('Monthly Rent (${CountryService.config.currencyCode})'),
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
                  border: Border.all(
                    color: _locationConfirmed ? const Color(0xFF2C2C2E) : Colors.amber.withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.my_location, color: _locationConfirmed ? Colors.white : Colors.amber),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _locationConfirmed
                            ? 'Coordinates: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}'
                            : 'Required -- tap to pin the exact location on the map',
                        style: TextStyle(color: _locationConfirmed ? Colors.white : Colors.amber, fontSize: 14),
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
              activeColor: Colors.white,
              onChanged: (val) => setState(() => _furnished = val!),
            ),
            CheckboxListTile(
              title: const Text('Parking Available', style: TextStyle(color: Colors.white)),
              value: _parking,
              activeColor: Colors.white,
              onChanged: (val) => setState(() => _parking = val!),
            ),
            CheckboxListTile(
              title: const Text('WiFi Internet', style: TextStyle(color: Colors.white)),
              value: _wifi,
              activeColor: Colors.white,
              onChanged: (val) => setState(() => _wifi = val!),
            ),
            CheckboxListTile(
              title: const Text('24hr Water Supply', style: TextStyle(color: Colors.white)),
              value: _water,
              activeColor: Colors.white,
              onChanged: (val) => setState(() => _water = val!),
            ),
            CheckboxListTile(
              title: const Text('Security Guard / CCTV', style: TextStyle(color: Colors.white)),
              value: _security,
              activeColor: Colors.white,
              onChanged: (val) => setState(() => _security = val!),
            ),
            CheckboxListTile(
              title: const Text('Balcony View', style: TextStyle(color: Colors.white)),
              value: _balcony,
              activeColor: Colors.white,
              onChanged: (val) => setState(() => _balcony = val!),
            ),
            CheckboxListTile(
              title: const Text('Pet Friendly', style: TextStyle(color: Colors.white)),
              value: _petFriendly,
              activeColor: Colors.white,
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
