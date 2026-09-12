import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/pages/profile/phone_verification_page.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/location_service.dart';
import 'package:roost_app/widgets/property/property_card.dart';
import 'package:roost_app/services/country_service.dart';

// ─── Amenity descriptor ────────────────────────────────────────────────────

class _Amenity {
  const _Amenity({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });
  final String key;
  final String label;
  final IconData icon;
  final Color color;
}

const _amenities = <_Amenity>[
  // Comfort & Essentials
  _Amenity(key: 'furnished',   label: 'Furnished',             icon: Icons.chair_outlined,                  color: Color(0xFF6C63FF)),
  _Amenity(key: 'wifi',        label: 'WiFi / Fiber',           icon: Icons.wifi,                            color: Color(0xFF00C896)),
  _Amenity(key: 'water',       label: '24hr Water / Borehole', icon: Icons.water_drop_outlined,             color: Color(0xFF29B6F6)),
  _Amenity(key: 'generator',   label: 'Backup Generator',      icon: Icons.power_outlined,                  color: Color(0xFFFFB74D)),
  _Amenity(key: 'solar',       label: 'Solar Water Heater',    icon: Icons.wb_sunny_outlined,               color: Color(0xFFFFD54F)),
  _Amenity(key: 'ac',          label: 'Air Conditioning',      icon: Icons.ac_unit,                         color: Color(0xFF81D4FA)),
  _Amenity(key: 'heating',     label: 'Heating',               icon: Icons.local_fire_department_outlined,  color: Color(0xFFFF8A65)),
  _Amenity(key: 'laundry',     label: 'In-Unit Laundry',       icon: Icons.local_laundry_service_outlined,  color: Color(0xFF90CAF9)),
  _Amenity(key: 'dstv',        label: 'DSTV / Cable TV',       icon: Icons.tv_outlined,                     color: Color(0xFFAB47BC)),

  // Security & Building
  _Amenity(key: 'security',    label: 'CCTV & Security',       icon: Icons.security,                        color: Color(0xFFFF9F43)),
  _Amenity(key: 'fence',       label: 'Electric Fence',        icon: Icons.fence,                           color: Color(0xFFFF7043)),
  _Amenity(key: 'intercom',    label: 'Intercom Access',       icon: Icons.doorbell_outlined,               color: Color(0xFFBA68C8)),
  _Amenity(key: 'elevator',    label: 'Elevator / Lift',       icon: Icons.elevator_outlined,               color: Color(0xFF4DB6AC)),
  _Amenity(key: 'parking',     label: 'Dedicated Parking',     icon: Icons.local_parking_outlined,          color: Color(0xFF4FC3F7)),
  _Amenity(key: 'caretaker',   label: 'On-site Caretaker',     icon: Icons.person_pin_outlined,             color: Color(0xFFA1887F)),

  // Space & Comfort
  _Amenity(key: 'balcony',     label: 'Private Balcony',       icon: Icons.deck_outlined,                   color: Color(0xFFA5D6A7)),
  _Amenity(key: 'rooftop',     label: 'Rooftop Terrace',       icon: Icons.apartment_outlined,              color: Color(0xFFB39DDB)),
  _Amenity(key: 'garden',      label: 'Garden / Lawn',         icon: Icons.grass_outlined,                  color: Color(0xFF81C784)),
  _Amenity(key: 'storage',     label: 'Storage Unit',          icon: Icons.inventory_2_outlined,            color: Color(0xFFDCE775)),

  // Leisure & Services
  _Amenity(key: 'pool',        label: 'Swimming Pool',         icon: Icons.pool,                            color: Color(0xFF4DD0E1)),
  _Amenity(key: 'gym',         label: 'Gym & Fitness',         icon: Icons.fitness_center,                  color: Color(0xFFFF8A65)),
  _Amenity(key: 'playArea',    label: 'Kids Play Area',        icon: Icons.child_care_outlined,             color: Color(0xFFF48FB1)),
  _Amenity(key: 'petFriendly', label: 'Pet Friendly',          icon: Icons.pets,                            color: Color(0xFFEF9A9A)),
  _Amenity(key: 'cleaning',    label: 'Housekeeping',          icon: Icons.cleaning_services_outlined,      color: Color(0xFF80CBC4)),
  _Amenity(key: 'garbage',     label: 'Garbage Collection',    icon: Icons.delete_outline,                  color: Color(0xFFB0BEC5)),
  _Amenity(key: 'wheelchair',  label: 'Wheelchair Access',     icon: Icons.accessible,                      color: Color(0xFF9FA8DA)),
];

// ─── House type options ────────────────────────────────────────────────────

const _houseTypes = ['BEDSITTER', 'STUDIO', '1BR', '2BR', '3BR+'];

const _houseTypeLabels = {
  'BEDSITTER': 'Bedsitter',
  'STUDIO': 'Studio',
  '1BR': '1 Bed',
  '2BR': '2 Bed',
  '3BR+': '3 Bed+',
};

// ─── Step labels ──────────────────────────────────────────────────────────

const _stepLabels = ['Photos', 'Basics', 'Location', 'Amenities', 'Contact', 'Review'];

// ─── Main widget ──────────────────────────────────────────────────────────

class AddPropertyPage extends StatefulWidget {
  const AddPropertyPage({super.key, this.editingProperty});

  /// When set, the page opens pre-filled with this listing\'s data and
  /// submits as an update (PUT) instead of creating a new listing.
  final Property? editingProperty;

  @override
  State<AddPropertyPage> createState() => _AddPropertyPageState();
}

class _AddPropertyPageState extends State<AddPropertyPage> {
  int _step = 0;
  bool _isLoading = false;
  bool _movingForward = true;

  final _titleCtrl       = TextEditingController();
  final _buildingNameCtrl= TextEditingController();
  final _locationCtrl    = TextEditingController();
  final _priceCtrl       = TextEditingController();
  final _depositCtrl     = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _phoneCtrl       = TextEditingController();

  // Stepper-based instead of raw text fields
  int _bedrooms  = 1;
  int _bathrooms = 1;

  String _houseType = '1BR';
  double? _latitude;
  double? _longitude;
  bool _locationConfirmed = false;
  bool _gpsVerified   = false;
  bool _checkingGps   = false;

  // Amenity toggles — keyed by _Amenity.key
  final Map<String, bool> _amenityState = {
    'furnished':   false,
    'parking':     false,
    'wifi':        false,
    'water':       true,
    'security':    true,
    'balcony':     false,
    'petFriendly': false,
  };
  final List<String> _customAmenities = [];

  static const int _minPhotos = 3;
  static const int _maxPhotos = 10;
  final List<String> _imageUrls = [];
  String? _videoUrl;
  final ImagePicker _picker = ImagePicker();
  bool _uploadingPhotos = false;
  int  _uploadDone  = 0;
  int  _uploadTotal = 0;
  bool _uploadingVideo = false;
  bool _autosaving = false;
  int? _draftId;

  // Document Upload & Verification Checkpoints
  final List<String> _documentUrls = [];
  String _selectedDocType = 'Title Deed / Ownership';
  bool _uploadingDocument = false;

  bool get _hasPhoneVerified => _phoneCtrl.text.trim().isNotEmpty;
  bool get _hasGpsVerified => _gpsVerified;
  bool get _hasDocUploaded => _documentUrls.isNotEmpty;

  int get _verificationScore =>
      (_hasPhoneVerified ? 1 : 0) +
      (_hasGpsVerified ? 1 : 0) +
      (_hasDocUploaded ? 1 : 0);

  bool get _isEarnedVerified => _verificationScore == 3;

  final Map<String, String> _errors = {};

  void _clearError(String key) {
    if (_errors.containsKey(key)) setState(() => _errors.remove(key));
  }

  bool get _busy => _isLoading || _uploadingPhotos || _uploadingVideo || _autosaving;
  bool get _isEditing => widget.editingProperty != null;

  // ── Lifecycle ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _draftId = widget.editingProperty?.id;
    final p = widget.editingProperty;
    if (p == null) return;

    _titleCtrl.text        = p.title;
    _buildingNameCtrl.text = p.buildingName ?? '';
    _locationCtrl.text     = p.location;
    _priceCtrl.text = p.price == p.price.roundToDouble()
        ? p.price.toInt().toString()
        : p.price.toString();
    _depositCtrl.text     = p.deposit ?? '';
    _bedrooms             = p.bedrooms;
    _bathrooms            = p.bathrooms;
    _descriptionCtrl.text = p.description;
    _phoneCtrl.text       = p.landlordPhone;
    _houseType            = p.houseType;

    if (p.latitude != null && p.longitude != null) {
      _latitude          = p.latitude;
      _longitude         = p.longitude;
      _locationConfirmed = true;
    }
    _gpsVerified = p.gpsVerified;
    _amenityState['furnished']   = p.furnished;
    _amenityState['parking']     = p.parking;
    _amenityState['wifi']        = p.wifi;
    _amenityState['water']       = p.water;
    _amenityState['security']    = p.security;
    _amenityState['balcony']     = p.balcony;
    _amenityState['petFriendly'] = p.petFriendly;

    _imageUrls.addAll(p.imageUrls);
    _documentUrls.addAll(p.documentUrls);
    _customAmenities.addAll(p.customAmenities);
    _videoUrl = p.videoUrl;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _buildingNameCtrl.dispose();
    _locationCtrl.dispose();
    _priceCtrl.dispose();
    _depositCtrl.dispose();
    _descriptionCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ── Validation ─────────────────────────────────────────────────────────

  bool _validateStep(int step) {
    final errors = <String, String>{};
    switch (step) {
      case 0:
        if (_imageUrls.length < _minPhotos) {
          errors['photos'] = 'Add at least $_minPhotos photos to continue';
        }
        break;
      case 1:
        if (_titleCtrl.text.trim().isEmpty) {
          errors['title'] = 'Give your listing a title';
        }
        final price = double.tryParse(_priceCtrl.text.trim());
        if (_priceCtrl.text.trim().isEmpty) {
          errors['price'] = 'Enter the monthly rent';
        } else if (price == null || price <= 0) {
          errors['price'] = 'Enter a valid amount';
        }
        break;
      case 2:
        if (_locationCtrl.text.trim().isEmpty) {
          errors['locationText'] = 'Add a neighborhood or street';
        }
        if (!_locationConfirmed) {
          errors['gps'] = 'Use your current location to continue';
        }
        break;
      case 3:
        break;
      case 4:
        if (_phoneCtrl.text.trim().isEmpty) {
          errors['phone'] = 'Add a contact phone number';
        }
        break;
    }
    setState(() {
      _errors..clear()..addAll(errors);
    });
    return errors.isEmpty;
  }

  // ── Location ──────────────────────────────────────────────────────────

  Future<void> _captureLocation() async {
    if (_checkingGps) return;
    setState(() => _checkingGps = true);
    try {
      final position = await LocationService.getCurrentPosition();
      if (position == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn\'t get your location. Make sure location access is allowed for Roost, then try again.")),
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _latitude          = position.latitude;
        _longitude         = position.longitude;
        _locationConfirmed = true;
        _gpsVerified       = false;
      });
      try {
        final status = _isEditing ? widget.editingProperty!.status : 'DRAFT';
        final id = await _persist(_buildPayload(status: status));
        if (id != null) {
          await ApiService.post('/api/properties/$id/verify-gps', {
            'latitude':  position.latitude,
            'longitude': position.longitude,
          });
          if (mounted) setState(() => _gpsVerified = true);
        }
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _checkingGps = false);
    }
  }

  // ── Photos / Video ────────────────────────────────────────────────────

  Future<void> _pickFromGallery() async {
    final remaining = _maxPhotos - _imageUrls.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maximum $_maxPhotos photos per listing')),
      );
      return;
    }
    setState(() => _uploadingPhotos = true);
    try {
      final files = await _picker.pickMultiImage();
      if (files.isEmpty) return;
      final toUpload = files.take(remaining).toList();
      if (files.length > remaining && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Only added $remaining — maximum $_maxPhotos photos')),
        );
      }
      await _uploadPhotos(toUpload);
    } finally {
      if (mounted) setState(() => _uploadingPhotos = false);
    }
  }

  Future<void> _takePhoto() async {
    setState(() => _uploadingPhotos = true);
    try {
      while (_imageUrls.length < _maxPhotos) {
        final file = await _picker.pickImage(source: ImageSource.camera);
        if (file == null) return;
        await _uploadPhotos([file]);
        if (!mounted) return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Maximum $_maxPhotos photos per listing')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhotos = false);
    }
  }

  Future<void> _uploadPhotos(List<XFile> files) async {
    setState(() {
      _uploadDone  = 0;
      _uploadTotal = files.length;
    });
    for (final file in files) {
      try {
        final bytes  = await file.readAsBytes();
        final result = await ApiService.post('/api/properties/upload-photo', {
          'data': base64Encode(bytes),
        });
        final url = result is Map ? result['url'] as String? : null;
        if (url != null && mounted) setState(() => _imageUrls.add(url));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('A photo failed to upload: $e')),
          );
        }
      }
      if (mounted) setState(() => _uploadDone++);
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    setState(() => _uploadingVideo = true);
    try {
      final file = await _picker.pickVideo(
          source: source, maxDuration: const Duration(seconds: 60));
      if (file == null) return;
      final bytes  = await file.readAsBytes();
      final result = await ApiService.post('/api/properties/upload-video', {
        'data': base64Encode(bytes),
      });
      final url = result is Map ? result['url'] as String? : null;
      if (url != null && mounted) setState(() => _videoUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingVideo = false);
    }
  }

  void _removeVideo()           => setState(() => _videoUrl = null);
  void _removePhoto(String url) => setState(() => _imageUrls.remove(url));

  // ── Persistence ────────────────────────────────────────────────────────

  Map<String, dynamic> _buildPayload({required String status}) {
    final rawPhone = _phoneCtrl.text.trim();
    final dialCode = CountryService.config.dialCode;
    final fullPhone = rawPhone.isEmpty
        ? ''
        : (rawPhone.startsWith('+') ? rawPhone : '$dialCode$rawPhone');
    final depText = _depositCtrl.text.trim();

    return {
      'title':       _titleCtrl.text.trim(),
      'buildingName': _buildingNameCtrl.text.trim().isEmpty
          ? null
          : _buildingNameCtrl.text.trim(),
      'location':    _locationCtrl.text.trim(),
      'price':       double.tryParse(_priceCtrl.text.trim()) ?? 0.0,
      'deposit':     depText.isEmpty ? null : depText,
      'bedrooms':    _bedrooms,
      'bathrooms':   _bathrooms,
      'houseType':   _houseType,
      'type':        'RENTAL',
      'available':   _isEditing ? widget.editingProperty!.available : true,
      'verified':    _isEditing ? widget.editingProperty!.verified  : false,
      'landlordPhone': fullPhone,
      'description': _descriptionCtrl.text.trim(),
      if (_imageUrls.isNotEmpty) 'imageUrl': _imageUrls.first,
      'imageUrls':   _imageUrls,
      'videoUrl':    _videoUrl,
      'latitude':    _latitude,
      'longitude':   _longitude,
      'furnished':   _amenityState['furnished']   ?? false,
      'parking':     _amenityState['parking']     ?? false,
      'wifi':        _amenityState['wifi']        ?? false,
      'water':       _amenityState['water']       ?? true,
      'security':    _amenityState['security']    ?? true,
      'balcony':     _amenityState['balcony']     ?? false,
      'petFriendly': _amenityState['petFriendly'] ?? false,
      'ac':          _amenityState['ac']          ?? false,
      'heating':     _amenityState['heating']     ?? false,
      'laundry':     _amenityState['laundry']     ?? false,
      'dstv':        _amenityState['dstv']        ?? false,
      'fence':       _amenityState['fence']       ?? false,
      'intercom':    _amenityState['intercom']    ?? false,
      'elevator':    _amenityState['elevator']    ?? false,
      'caretaker':   _amenityState['caretaker']   ?? false,
      'rooftop':     _amenityState['rooftop']     ?? false,
      'garden':      _amenityState['garden']      ?? false,
      'storage':     _amenityState['storage']     ?? false,
      'pool':        _amenityState['pool']        ?? false,
      'gym':         _amenityState['gym']         ?? false,
      'playArea':    _amenityState['playArea']    ?? false,
      'cleaning':    _amenityState['cleaning']    ?? false,
      'garbage':     _amenityState['garbage']     ?? false,
      'wheelchair':  _amenityState['wheelchair']  ?? false,
      'solar':       _amenityState['solar']       ?? false,
      'generator':   _amenityState['generator']   ?? false,
      'moveInDate':  'Immediate',
      'country':     CountryService.config.code,
      'status':      status,
      'customAmenities': _customAmenities,
    };
  }

  Property _buildPreviewProperty() {
    final rawPhone = _phoneCtrl.text.trim();
    final dialCode = CountryService.config.dialCode;
    final fullPhone = rawPhone.isEmpty
        ? ''
        : (rawPhone.startsWith('+') ? rawPhone : '$dialCode$rawPhone');

    return Property(
      title:        _titleCtrl.text.trim(),
      buildingName: _buildingNameCtrl.text.trim().isEmpty
          ? null
          : _buildingNameCtrl.text.trim(),
      description:  _descriptionCtrl.text.trim(),
      location:     _locationCtrl.text.trim(),
      price:        double.tryParse(_priceCtrl.text.trim()) ?? 0.0,
      bedrooms:     _bedrooms,
      bathrooms:    _bathrooms,
      type:         'RENTAL',
      houseType:    _houseType,
      landlordPhone: fullPhone,
      available:    _isEditing ? widget.editingProperty!.available : true,
      verified:     _isEditing ? widget.editingProperty!.verified  : _isEarnedVerified,
      gpsVerified:  _gpsVerified,
      documentVerified: _hasDocUploaded,
      documentUrls: _documentUrls,
      imageUrl:     _imageUrls.isNotEmpty ? _imageUrls.first : null,
      imageUrls:    _imageUrls,
      videoUrl:     _videoUrl,
      latitude:     _latitude,
      longitude:    _longitude,
      furnished:    _amenityState['furnished']   ?? false,
      parking:      _amenityState['parking']     ?? false,
      water:        _amenityState['water']       ?? true,
      wifi:         _amenityState['wifi']        ?? false,
      security:     _amenityState['security']    ?? true,
      balcony:      _amenityState['balcony']     ?? false,
      petFriendly:  _amenityState['petFriendly'] ?? false,
      ac:           _amenityState['ac']          ?? false,
      heating:      _amenityState['heating']     ?? false,
      laundry:      _amenityState['laundry']     ?? false,
      dstv:         _amenityState['dstv']        ?? false,
      fence:        _amenityState['fence']       ?? false,
      intercom:     _amenityState['intercom']    ?? false,
      elevator:     _amenityState['elevator']    ?? false,
      caretaker:    _amenityState['caretaker']   ?? false,
      rooftop:      _amenityState['rooftop']     ?? false,
      garden:       _amenityState['garden']      ?? false,
      storage:      _amenityState['storage']     ?? false,
      pool:         _amenityState['pool']        ?? false,
      gym:          _amenityState['gym']         ?? false,
      playArea:     _amenityState['playArea']    ?? false,
      cleaning:     _amenityState['cleaning']    ?? false,
      garbage:      _amenityState['garbage']     ?? false,
      wheelchair:   _amenityState['wheelchair']  ?? false,
      solar:        _amenityState['solar']       ?? false,
      generator:    _amenityState['generator']   ?? false,
      deposit:      _depositCtrl.text.trim().isEmpty ? null : _depositCtrl.text.trim(),
      moveInDate:   'Immediate',
      country:      CountryService.config.code,
      customAmenities: _customAmenities,
    );
  }

  Future<int?> _persist(Map<String, dynamic> payload) async {
    if (_draftId != null) {
      try {
        await ApiService.put('/api/properties/$_draftId', payload);
        return _draftId;
      } on ApiException catch (e) {
        if (e.message.contains('not found') || e.message.contains('404')) {
          _draftId = null;
        } else {
          rethrow;
        }
      } catch (_) {
        // Fall back to POST if unknown client-side error
      }
    }
    final result = await ApiService.post('/api/properties', payload);
    final newId  = result is Map ? result['id'] as int? : null;
    if (newId != null) _draftId = newId;
    return _draftId;
  }

  void _autosaveDraft() async {
    if (_titleCtrl.text.trim().isEmpty && _imageUrls.isEmpty && !_isEditing) return;
    if (_autosaving) return;
    if (mounted) setState(() => _autosaving = true);
    try {
      await _persist(_buildPayload(status: 'DRAFT'));
    } catch (_) {} finally {
      if (mounted) setState(() => _autosaving = false);
    }
  }

  Future<bool> _ensurePhoneVerified() async {
    try {
      final me = await ApiService.get('/api/users/me');
      if (me['phoneVerified'] == true) return true;
    } catch (_) {}
    if (!mounted) return false;
    final verified = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PhoneVerificationPage()),
    );
    return verified == true;
  }

  Future<void> _submitProperty() async {
    for (var s = 0; s <= 4; s++) {
      if (!_validateStep(s)) {
        if (!mounted) return;
        setState(() => _step = s);
        return;
      }
    }
    if (!await _ensurePhoneVerified()) return;
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await _persist(_buildPayload(status: 'PUBLISHED'));
      if (!mounted) return;
      await _showSuccessDialog();
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

  Future<void> _showSuccessDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SuccessDialog(isEditing: _isEditing),
    );
    if (mounted) Navigator.pop(context, true);
  }

  void _nextStep() {
    if (_busy) return;
    final lastFieldStep = _stepLabels.length - 2;
    if (_step <= lastFieldStep && !_validateStep(_step)) return;
    HapticFeedback.lightImpact();
    if (_step < _stepLabels.length - 1) {
      _autosaveDraft();
      setState(() {
        _movingForward = true;
        _step++;
      });
    } else {
      _submitProperty();
    }
  }

  void _prevStep() {
    if (_step > 0 && !_busy) {
      HapticFeedback.selectionClick();
      setState(() {
        _movingForward = false;
        _step--;
      });
    }
  }

  void _jumpToStep(int step) {
    if (_busy) return;
    setState(() {
      _movingForward = false;
      _step = step;
    });
  }

  Future<void> _saveDraft() async {
    setState(() => _isLoading = true);
    try {
      await _persist(_buildPayload(status: 'DRAFT'));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft saved. Resume it anytime from your listings.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save draft: $e')),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _isEditing ? 'Edit Listing' : 'List a Property',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : _saveDraft,
            child: Text('Save Draft',
                style: TextStyle(
                    color: _busy ? Colors.white24 : Colors.white60,
                    fontSize: 14)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            children: [
              _buildProgressSection(),
              const SizedBox(height: 20),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    final offsetTween = Tween<Offset>(
                      begin: Offset(_movingForward ? 0.20 : -0.20, 0),
                      end: Offset.zero,
                    );
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: animation.drive(
                            offsetTween.chain(CurveTween(curve: Curves.easeOutCubic))),
                        child: child,
                      ),
                    );
                  },
                  child: SingleChildScrollView(
                    key: ValueKey(_step),
                    child: _buildStepContent(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildNavButtons(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Progress bar + step label ─────────────────────────────────────────

  Widget _buildProgressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(_stepLabels.length, (idx) {
            final active   = idx == _step;
            final complete = idx < _step;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                height: 5,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  color: complete
                      ? Colors.white
                      : active
                          ? Colors.white
                          : const Color(0xFF2C2C2E),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.3),
                            blurRadius: 6,
                          )
                        ]
                      : null,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              'Step ${_step + 1} of ${_stepLabels.length}',
              style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2),
            ),
            const SizedBox(width: 8),
            Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                  color: Colors.grey[700], shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              _stepLabels[_step],
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5),
            ),
          ],
        ),
      ],
    );
  }

  // ── Navigation buttons ────────────────────────────────────────────────

  Widget _buildNavButtons() {
    final isLastStep = _step == _stepLabels.length - 1;
    final nextLabel  = isLastStep
        ? (_isEditing ? 'Save Changes' : 'Publish Listing')
        : 'Continue';

    return Row(
      children: [
        if (_step > 0) ...[
          SizedBox(
            width: 80,
            child: GestureDetector(
              onTap: _busy ? null : _prevStep,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: const Color(0xFF2C2C2E), width: 1.2),
                ),
                child: Center(
                  child: Icon(Icons.arrow_back_rounded,
                      color: _busy ? Colors.white24 : Colors.white, size: 20),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: GestureDetector(
            onTap: _busy ? null : _nextStep,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: _busy ? Colors.white54 : Colors.white,
              ),
              child: Center(
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.black54),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            nextLabel,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (!isLastStep) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_rounded,
                                color: Colors.black, size: 18),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Step content dispatcher ──────────────────────────────────────────

  Widget _buildStepContent() {
    switch (_step) {
      case 0:  return _buildPhotosStep();
      case 1:  return _buildBasicsStep();
      case 2:  return _buildLocationStep();
      case 3:  return _buildAmenitiesStep();
      case 4:  return _buildContactStep();
      default: return _buildReviewStep();
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // STEP 0 — Photos
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildPhotosStep() {
    final hasMin = _imageUrls.length >= _minPhotos;
    final progress = _uploadTotal > 0 ? _uploadDone / _uploadTotal : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeader(
          stepNumber: 1,
          title: 'Property Photos',
          subtitle: 'Clear, bright shots get 3× more inquiries',
        ),
        const SizedBox(height: 20),

        // Status pill
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: (hasMin ? const Color(0xFF00C896) : Colors.amber)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: (hasMin ? const Color(0xFF00C896) : Colors.amber)
                  .withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasMin ? Icons.check_circle_outline : Icons.photo_camera_outlined,
                size: 14,
                color: hasMin ? const Color(0xFF00C896) : Colors.amber,
              ),
              const SizedBox(width: 7),
              Text(
                hasMin
                    ? '${_imageUrls.length} photos added ✓'
                    : '${_imageUrls.length}/$_minPhotos photos — add ${_minPhotos - _imageUrls.length} more',
                style: TextStyle(
                  color: hasMin ? const Color(0xFF00C896) : Colors.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Upload action tiles
        if (!_uploadingPhotos)
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  icon: Icons.camera_alt_outlined,
                  label: 'Camera',
                  onTap: _takePhoto,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionTile(
                  icon: Icons.photo_library_outlined,
                  label: 'Gallery',
                  onTap: _pickFromGallery,
                ),
              ),
            ],
          ),

        // Upload progress
        if (_uploadingPhotos) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white70),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Uploading $_uploadDone of $_uploadTotal…',
                      style:
                          TextStyle(color: Colors.grey[300], fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: const Color(0xFF2C2C2E),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Empty drop-zone
        if (_imageUrls.isEmpty && !_uploadingPhotos) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _errors.containsKey('photos')
                    ? Colors.redAccent.withValues(alpha: 0.6)
                    : const Color(0xFF2C2C2E),
                width: 1.5,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.add_a_photo_outlined,
                    color: Colors.grey[600], size: 32),
                const SizedBox(height: 14),
                const Text(
                  'No photos yet',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  'Natural light & landscape shots of\neach room get the most views',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.grey[600], fontSize: 12.5, height: 1.4),
                ),
                if (_errors.containsKey('photos')) ...[
                  const SizedBox(height: 10),
                  Text(
                    _errors['photos']!,
                    style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ],

        // Photo grid
        if (_imageUrls.isNotEmpty) ...[
          const SizedBox(height: 16),
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
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                builder: (context, value, child) => Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: Transform.scale(
                      scale: 0.8 + (0.2 * value), child: child),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFF1C1C1E),
                                child: const Icon(
                                    Icons.broken_image_outlined,
                                    color: Colors.grey),
                              )),
                    ),
                    if (index == 0)
                      Positioned(
                        left: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(6)),
                          child: const Text('Cover',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: GestureDetector(
                        onTap: () => _removePhoto(url),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],

        // Divider + video section
        const SizedBox(height: 28),
        const Divider(color: Colors.white12),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.videocam_outlined,
                color: Colors.white54, size: 18),
            const SizedBox(width: 8),
            const Text('Walkthrough Video',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(4)),
              child: const Text('Optional',
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'A short walkthrough helps renters picture the space',
          style: TextStyle(color: Colors.grey[600], fontSize: 12.5),
        ),
        const SizedBox(height: 14),
        if (_uploadingVideo)
          Row(children: [
            const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 10),
            Text('Uploading video…',
                style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ])
        else if (_videoUrl != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2C2C2E)),
            ),
            child: Row(children: [
              const Icon(Icons.videocam, color: Colors.white70),
              const SizedBox(width: 12),
              const Expanded(
                  child: Text('Video attached',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600))),
              GestureDetector(
                  onTap: _removeVideo,
                  child: const Icon(Icons.close,
                      color: Colors.grey, size: 20)),
            ]),
          )
        else
          Row(children: [
            Expanded(
                child: _ActionTile(
                    icon: Icons.videocam_outlined,
                    label: 'Record',
                    onTap: () => _pickVideo(ImageSource.camera))),
            const SizedBox(width: 12),
            Expanded(
                child: _ActionTile(
                    icon: Icons.video_library_outlined,
                    label: 'Gallery',
                    onTap: () => _pickVideo(ImageSource.gallery))),
          ]),
        const SizedBox(height: 8),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // STEP 1 — Basics
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildBasicsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeader(
          stepNumber: 2,
          title: 'Basic Information',
          subtitle: 'Title, type, rent, and rooms',
        ),
        const SizedBox(height: 24),

        TextField(
          controller: _titleCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('Listing title (e.g. Modern 2BR in Kilimani)',
              errorText: _errors['title']),
          onChanged: (_) => _clearError('title'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _buildingNameCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('Building / apartment name (optional)'),
        ),
        const SizedBox(height: 20),

        // House type chip selector
        Text('House Type',
            style:
                TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _houseTypes.map((type) {
              final selected = _houseType == type;
              return GestureDetector(
                onTap: () => setState(() => _houseType = type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white
                        : const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: selected
                            ? Colors.white
                            : const Color(0xFF3A3A3C)),
                  ),
                  child: Text(
                    _houseTypeLabels[type] ?? type,
                    style: TextStyle(
                      color: selected ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 20),

        // Price + deposit
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(
                    'Monthly rent (${CountryService.config.currencyCode})',
                    errorText: _errors['price'],
                    prefixIcon: const Icon(Icons.attach_money,
                        color: Colors.white38, size: 18)),
                onChanged: (_) => _clearError('price'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _depositCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Deposit terms (optional)'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Beds / Baths steppers
        Text('Rooms',
            style:
                TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StepperField(
                label: 'Bedrooms',
                value: _bedrooms,
                min: 0,
                max: 20,
                onChanged: (v) => setState(() => _bedrooms = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StepperField(
                label: 'Bathrooms',
                value: _bathrooms,
                min: 0,
                max: 10,
                onChanged: (v) => setState(() => _bathrooms = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // STEP 2 — Location
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildLocationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeader(
          stepNumber: 3,
          title: 'Location',
          subtitle: 'Neighbourhood + GPS confirmation earns your Verified badge',
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _locationCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration(
              'Neighbourhood / street (e.g. Kilimani, Chania Ave)',
              errorText: _errors['locationText'],
              prefixIcon:
                  const Icon(Icons.location_on_outlined, color: Colors.white38, size: 18)),
          onChanged: (_) => _clearError('locationText'),
        ),
        const SizedBox(height: 20),
        if (!_locationConfirmed)
          _GpsPromptCard(
            hasError: _errors.containsKey('gps'),
            isChecking: _checkingGps,
            onTap: _captureLocation,
          )
        else
          _GpsConfirmedCard(
            latitude: _latitude!,
            longitude: _longitude!,
            verified: _gpsVerified,
            isChecking: _checkingGps,
            onUpdate: _captureLocation,
          ),
        const SizedBox(height: 24),
        _buildVerificationChecklistCard(),
        const SizedBox(height: 20),
        _buildDocumentUploadSection(),
      ],
    );
  }

  Widget _buildVerificationChecklistCard() {
    final bool isEarned = _isEarnedVerified;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEarned
              ? Colors.greenAccent.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: [
          if (isEarned)
            BoxShadow(
              color: Colors.greenAccent.withValues(alpha: 0.15),
              blurRadius: 16,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Colors.greenAccent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Earn Your VERIFIED Badge',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isEarned ? Colors.greenAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_verificationScore / 3 Done',
                  style: TextStyle(
                    color: isEarned ? Colors.greenAccent : Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _verificationScore / 3.0,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(isEarned ? Colors.greenAccent : const Color(0xFF00C896)),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 16),
          _buildChecklistItem(
            title: 'Phone Number Authenticated',
            subtitle: 'Confirmed via SMS OTP code',
            isComplete: _hasPhoneVerified,
            icon: Icons.phone_android_rounded,
          ),
          const SizedBox(height: 10),
          _buildChecklistItem(
            title: 'On-Site GPS Location Confirmed',
            subtitle: 'Captured live coordinates at listing location',
            isComplete: _hasGpsVerified,
            icon: Icons.my_location_rounded,
          ),
          const SizedBox(height: 10),
          _buildChecklistItem(
            title: 'Ownership / Utility Proof Uploaded',
            subtitle: 'Title deed, utility bill or ID photo attached',
            isComplete: _hasDocUploaded,
            icon: Icons.description_outlined,
          ),
          const SizedBox(height: 14),
          if (isEarned)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_rounded, color: Colors.greenAccent, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '🎉 All requirements met! This property will feature the official VERIFIED checkmark badge.',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, height: 1.3),
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              'Complete all 3 verification checkpoints above to earn top feed placement and the official VERIFIED badge.',
              style: TextStyle(color: Colors.grey[400], fontSize: 12, height: 1.3),
            ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem({
    required String title,
    required String subtitle,
    required bool isComplete,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isComplete ? Colors.greenAccent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isComplete ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: isComplete ? Colors.greenAccent : Colors.grey[500],
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isComplete ? Colors.white : Colors.grey[300],
                  fontSize: 13,
                  fontWeight: isComplete ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentUploadSection() {
    const docTypes = [
      'Title Deed / Ownership',
      'Utility Bill (Water/Power)',
      'National ID / Passport',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upload Verification Documents',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Attach document proof (PDF, JPG, PNG) to confirm landlord authorization.',
          style: TextStyle(color: Colors.grey[400], fontSize: 13),
        ),
        const SizedBox(height: 14),

        // Document Type Selector Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: docTypes.map((type) {
              final isSelected = _selectedDocType == type;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  showCheckmark: false,
                  label: Text(
                    type,
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.grey[300],
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: Colors.white,
                  backgroundColor: const Color(0xFF1C1C1E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedDocType = type);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        // Upload Button
        OutlinedButton.icon(
          onPressed: _uploadingDocument ? null : _pickVerificationDocument,
          icon: _uploadingDocument
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.upload_file_rounded, size: 18),
          label: Text(_uploadingDocument ? 'Uploading Document...' : 'Attach $_selectedDocType'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),

        // Document List Cards
        if (_documentUrls.isNotEmpty) ...[
          const SizedBox(height: 14),
          Column(
            children: _documentUrls.asMap().entries.map((entry) {
              final idx = entry.key;
              final url = entry.value;
              final docTitle = url.split('/').last.replaceAll('_', ' ');
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            docTitle,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Verified Document Attached',
                            style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 18),
                      onPressed: () => _removeVerificationDocument(idx),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Future<void> _pickVerificationDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() => _uploadingDocument = true);
        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        setState(() {
          _documentUrls.add('${_selectedDocType.replaceAll(' ', '_')}_${file.name}');
          _uploadingDocument = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _uploadingDocument = false);
      }
    }
  }

  void _removeVerificationDocument(int index) {
    if (index >= 0 && index < _documentUrls.length) {
      setState(() {
        _documentUrls.removeAt(index);
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // STEP 3 — Amenities
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildAmenitiesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeader(
          stepNumber: 4,
          title: 'Amenities & Features',
          subtitle: 'Select all features available at your property',
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _amenities.map((a) {
            final on = _amenityState[a.key] ?? false;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _amenityState[a.key] = !on);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: (MediaQuery.of(context).size.width - 40 - 12) / 2,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: on
                      ? a.color.withValues(alpha: 0.12)
                      : const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: on
                        ? a.color.withValues(alpha: 0.5)
                        : const Color(0xFF2C2C2E),
                    width: 1.4,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(a.icon,
                        size: 20,
                        color: on ? a.color : Colors.grey[600]),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        a.label,
                        style: TextStyle(
                          color: on ? Colors.white : Colors.grey[400],
                          fontSize: 13,
                          fontWeight:
                              on ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (on)
                      Icon(Icons.check_circle_rounded,
                          size: 16, color: a.color),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 32),
        const Divider(color: Color(0xFF2C2C2E)),
        const SizedBox(height: 20),

        // ── Custom Amenities Section ─────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Custom Amenities',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add unique features not listed above',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
            GestureDetector(
              onTap: _showAddCustomAmenityDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF6C63FF), width: 1.2),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 16, color: Color(0xFF6C63FF)),
                    SizedBox(width: 4),
                    Text(
                      'Add Custom',
                      style: TextStyle(color: Color(0xFF6C63FF), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_customAmenities.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2C2C2E)),
            ),
            child: Row(
              children: [
                Icon(Icons.stars_outlined, color: Colors.grey[600], size: 20),
                const SizedBox(width: 12),
                Text(
                  'No custom amenities added yet',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _customAmenities.map((custom) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.6), width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars_rounded, size: 16, color: Color(0xFFFFD700)),
                    const SizedBox(width: 8),
                    Text(
                      custom,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _customAmenities.remove(custom));
                      },
                      child: Icon(Icons.close_rounded, size: 16, color: Colors.grey[400]),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _showAddCustomAmenityDialog() {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.stars_rounded, color: Color(0xFFFFD700), size: 22),
            SizedBox(width: 10),
            Text('Add Custom Amenity', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter any amenity or special feature available at your property:', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Amenity Name (e.g. Sauna, EV Charger)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isNotEmpty && !_customAmenities.contains(text)) {
                HapticFeedback.lightImpact();
                setState(() => _customAmenities.add(text));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add Amenity', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // STEP 4 — Contact + Description
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildContactStep() {
    const maxDesc = 500;
    final descLen = _descriptionCtrl.text.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeader(
          stepNumber: 5,
          title: 'Description & Contact',
          subtitle: 'How renters can reach you + a property description',
        ),
        const SizedBox(height: 24),

        // Phone with country prefix label
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                '${CountryService.config.flag}  ${CountryService.config.dialCode}',
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Phone number',
                    errorText: _errors['phone']),
                onChanged: (_) => _clearError('phone'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Description with char counter
        Stack(
          children: [
            TextField(
              controller: _descriptionCtrl,
              maxLines: 5,
              maxLength: maxDesc,
              style: const TextStyle(color: Colors.white),
              decoration:
                  _inputDecoration('Describe the property (optional)', counterText: ''),
              onChanged: (_) => setState(() {}),
            ),
            Positioned(
              bottom: 10,
              right: 12,
              child: Text(
                '$descLen / $maxDesc',
                style: TextStyle(
                    color: descLen > maxDesc * 0.9
                        ? Colors.amber
                        : Colors.grey[600],
                    fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // STEP 5 — Review
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildReviewStep() {
    final selectedStandard = _amenities
        .where((a) => _amenityState[a.key] == true)
        .map((a) => a.label);
    final selected = [...selectedStandard, ..._customAmenities];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeader(
          stepNumber: 6,
          title: 'Review Your Listing',
          subtitle: 'Everything looks right? Hit publish!',
        ),
        const SizedBox(height: 16),

        // Live preview card
        IgnorePointer(
          child: PropertyCard(
            property: _buildPreviewProperty(),
            margin: EdgeInsets.zero,
          ),
        ),

        const SizedBox(height: 24),

        _ReviewRow(
          icon: Icons.photo_library_outlined,
          title: 'Photos',
          value: '${_imageUrls.length} photo${_imageUrls.length == 1 ? '' : 's'} added',
          isOk: _imageUrls.length >= _minPhotos,
          onEdit: () => _jumpToStep(0),
        ),
        _ReviewRow(
          icon: Icons.home_outlined,
          title: 'Basics',
          value:
              '${_houseTypeLabels[_houseType] ?? _houseType} · ${CountryService.pricePerMonth(double.tryParse(_priceCtrl.text.trim()) ?? 0)}\n$_bedrooms bed · $_bathrooms bath',
          isOk: _titleCtrl.text.trim().isNotEmpty &&
              (double.tryParse(_priceCtrl.text.trim()) ?? 0) > 0,
          onEdit: () => _jumpToStep(1),
        ),
        _ReviewRow(
          icon: Icons.location_on_outlined,
          title: 'Location',
          value: _locationCtrl.text.trim().isEmpty
              ? '(not set)'
              : _locationCtrl.text.trim(),
          badge: _gpsVerified ? 'GPS verified' : null,
          badgeColor: _gpsVerified ? const Color(0xFF00C896) : null,
          isOk: _locationConfirmed && _locationCtrl.text.trim().isNotEmpty,
          onEdit: () => _jumpToStep(2),
        ),
        _ReviewRow(
          icon: Icons.check_circle_outline,
          title: 'Amenities',
          value: selected.isEmpty ? 'None selected' : selected.join(' · '),
          isOk: true,
          onEdit: () => _jumpToStep(3),
        ),
        _ReviewRow(
          icon: Icons.phone_outlined,
          title: 'Contact',
          value: _phoneCtrl.text.trim().isEmpty
              ? '(no phone)'
              : _phoneCtrl.text.trim(),
          isOk: _phoneCtrl.text.trim().isNotEmpty,
          onEdit: () => _jumpToStep(4),
        ),

        const SizedBox(height: 16),
        Center(
          child: Text(
            'By publishing you agree to our listing guidelines and confirm\nthis property is available for rent.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[700], fontSize: 11, height: 1.5),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── Shared input decoration ──────────────────────────────────────────

  InputDecoration _inputDecoration(
    String label, {
    String? errorText,
    Widget? prefixIcon,
    String? counterText,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
      filled: true,
      fillColor: const Color(0xFF1C1C1E),
      prefixIcon: prefixIcon,
      counterText: counterText,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white30, width: 1.2),
      ),
      errorText: errorText,
      errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.6),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Supporting widgets
// ─────────────────────────────────────────────────────────────────────────

/// Step heading: numbered badge + title + subtitle.
class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.stepNumber,
    required this.title,
    required this.subtitle,
  });
  final int stepNumber;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.4),
        ),
      ],
    );
  }
}

/// Tap-to-upload icon tile used in Photos step.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF3A3A3C)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white70, size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stepper widget for integer values (beds, baths).
class _StepperField extends StatelessWidget {
  const _StepperField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: value > min ? () => onChanged(value - 1) : null,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: value > min
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: value > min
                          ? const Color(0xFF3A3A3C)
                          : Colors.white12,
                    ),
                  ),
                  child: Icon(Icons.remove,
                      size: 16,
                      color: value > min ? Colors.white : Colors.white24),
                ),
              ),
              Text('$value',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: value < max ? () => onChanged(value + 1) : null,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: value < max
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: value < max
                          ? const Color(0xFF3A3A3C)
                          : Colors.white12,
                    ),
                  ),
                  child: Icon(Icons.add,
                      size: 16,
                      color: value < max ? Colors.white : Colors.white24),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// GPS prompt card shown before location is captured.
class _GpsPromptCard extends StatelessWidget {
  const _GpsPromptCard({
    required this.hasError,
    required this.isChecking,
    required this.onTap,
  });
  final bool hasError;
  final bool isChecking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasError
              ? Colors.redAccent.withValues(alpha: 0.6)
              : Colors.amber.withValues(alpha: 0.4),
          width: 1.3,
        ),
      ),
      child: Column(
        children: [
          // Animated ping icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.9, end: 1.1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOut,
            builder: (_, v, child) =>
                Transform.scale(scale: v, child: child),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.amber.withValues(alpha: 0.12),
              ),
              child: const Icon(Icons.my_location,
                  color: Colors.amber, size: 28),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Confirm your GPS location",
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            "Stand at the property and tap below.\nThis is what earns the Verified badge.",
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.grey[500], fontSize: 12.5, height: 1.4),
          ),
          if (hasError) ...[
            const SizedBox(height: 8),
            const Text('Required to continue',
                style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isChecking ? null : onTap,
              icon: isChecking
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black54))
                  : const Icon(Icons.my_location, size: 16),
              label: Text(
                  isChecking ? 'Getting location…' : 'Use My Current Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// GPS confirmed card (green glow, lat/lng, update link).
class _GpsConfirmedCard extends StatelessWidget {
  const _GpsConfirmedCard({
    required this.latitude,
    required this.longitude,
    required this.verified,
    required this.isChecking,
    required this.onUpdate,
  });
  final double latitude;
  final double longitude;
  final bool verified;
  final bool isChecking;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final color = verified ? const Color(0xFF00C896) : Colors.white54;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.3),
        boxShadow: verified
            ? [
                BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 16,
                    spreadRadius: 1)
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
              verified ? Icons.verified_rounded : Icons.location_on_rounded,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                verified ? "You're at this location — confirmed" : 'Location captured',
                style: TextStyle(
                    color: color, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          if (verified) ...[
            const SizedBox(height: 3),
            Text('This counts toward your Verified badge',
                style: TextStyle(
                    color: color.withValues(alpha: 0.8), fontSize: 12)),
          ],
          const SizedBox(height: 12),
          GestureDetector(
            onTap: isChecking ? null : onUpdate,
            child: Text(
              isChecking ? 'Updating…' : 'Update location',
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  decoration: TextDecoration.underline),
            ),
          ),
        ],
      ),
    );
  }
}

/// Review step row with icon, title, value, and inline edit link.
class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.isOk,
    required this.onEdit,
    this.badge,
    this.badgeColor,
  });
  final IconData icon;
  final String title;
  final String value;
  final bool isOk;
  final VoidCallback onEdit;
  final String? badge;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 18,
              color: isOk ? Colors.white60 : Colors.redAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(value,
                    style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12.5,
                        height: 1.4)),
                if (badge != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.verified_rounded,
                        size: 12, color: badgeColor ?? Colors.white54),
                    const SizedBox(width: 4),
                    Text(badge!,
                        style: TextStyle(
                            color: badgeColor ?? Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ]),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Edit',
                  style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Success dialog ─────────────────────────────────────────────────────────

class _SuccessDialog extends StatefulWidget {
  const _SuccessDialog({required this.isEditing});
  final bool isEditing;

  @override
  State<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<_SuccessDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade  = CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.5));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated checkmark
            ScaleTransition(
              scale: _scale,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00C896).withValues(alpha: 0.15),
                  border: Border.all(
                      color: const Color(0xFF00C896).withValues(alpha: 0.4),
                      width: 2),
                ),
                child: const Icon(Icons.check_rounded,
                    color: Color(0xFF00C896), size: 40),
              ),
            ),
            const SizedBox(height: 24),
            FadeTransition(
              opacity: _fade,
              child: Column(
                children: [
                  Text(
                    widget.isEditing ? 'Listing updated!' : 'You\'re live! 🚀',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isEditing
                        ? 'Your listing has been updated successfully.'
                        : 'Your property is now visible to renters.\nGood luck!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.grey[400], fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('View My Listings',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
