import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/pages/profile/phone_verification_page.dart';
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

  /// Tracks whether the last step change was forward (Next) or backward
  /// (Back), so the step transition animation can slide the right way --
  /// content entering from the right when advancing, from the left when
  /// going back, matching how directional wizards like this are
  /// conventionally expected to feel rather than a generic cross-fade.
  bool _movingForward = true;

  final _titleCtrl = TextEditingController();
  final _buildingNameCtrl = TextEditingController();
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
  String? _videoUrl;
  final ImagePicker _picker = ImagePicker();
  bool _uploadingPhotos = false;
  int _uploadDone = 0;
  int _uploadTotal = 0;
  bool _uploadingVideo = false;

  bool get _isEditing => widget.editingProperty != null;

  /// Tracks the id of whatever draft this wizard session is building,
  /// whether that's an existing listing passed in via editingProperty
  /// or one silently created by autosave partway through a fresh
  /// session. Once set, every subsequent save (autosave, explicit Save
  /// Draft, or final Publish) becomes a PUT against this id instead of
  /// a new POST -- otherwise autosaving on every step would create a
  /// new orphaned draft every time instead of updating the same one.
  int? _draftId;

  @override
  void initState() {
    super.initState();
    _draftId = widget.editingProperty?.id;
    final p = widget.editingProperty;
    if (p == null) return;

    _titleCtrl.text = p.title;
    _buildingNameCtrl.text = p.buildingName ?? '';
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
    _videoUrl = p.videoUrl;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _buildingNameCtrl.dispose();
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

  /// A single optional walkthrough video per listing -- picked from the
  /// gallery or recorded fresh, capped at 60s to keep uploads reasonable
  /// on mobile data (the backend independently caps by file size too;
  /// this is just a friendlier first line of defense). Replaces any
  /// previously attached video rather than allowing multiple, since the
  /// gallery/detail view is built around exactly one.
  Future<void> _pickVideo(ImageSource source) async {
    final file = await _picker.pickVideo(
      source: source,
      maxDuration: const Duration(seconds: 60),
    );
    if (file == null) return;

    setState(() => _uploadingVideo = true);
    try {
      final bytes = await file.readAsBytes();
      final result = await ApiService.post('/api/properties/upload-video', {
        'data': base64Encode(bytes),
      });
      final url = result is Map ? result['url'] as String? : null;
      if (url != null && mounted) {
        setState(() => _videoUrl = url);
      }
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

  void _removeVideo() {
    setState(() => _videoUrl = null);
  }

  void _removePhoto(String url) {
    setState(() => _imageUrls.remove(url));
  }

  /// Shared payload builder for every save path (autosave, explicit
  /// Save Draft, and final Publish) -- only the status differs between
  /// them, so this is the single place field mapping lives instead of
  /// three copies drifting apart over time.
  Map<String, dynamic> _buildPayload({required String status}) {
    return {
      'title': _titleCtrl.text.trim(),
      'buildingName': _buildingNameCtrl.text.trim().isEmpty ? null : _buildingNameCtrl.text.trim(),
      'location': _locationCtrl.text.trim(),
      'price': double.tryParse(_priceCtrl.text.trim()) ?? 0.0,
      'deposit': _depositCtrl.text.trim(),
      'bedrooms': int.tryParse(_bedroomsCtrl.text.trim()) ?? 1,
      'bathrooms': int.tryParse(_bathroomsCtrl.text.trim()) ?? 1,
      'houseType': _houseType,
      'type': 'RENTAL',
      // Preserves whatever the ORIGINAL listing's available/verified
      // status already was, if one was passed in -- an edit (or an
      // autosave of a listing that started life as one) shouldn't
      // silently re-publish something marked rented, or un-verify one
      // that passed verification, just because a field changed.
      'available': _isEditing ? widget.editingProperty!.available : true,
      'verified': _isEditing ? widget.editingProperty!.verified : false,
      'landlordPhone': _phoneCtrl.text.trim(),
      'description': _descriptionCtrl.text.trim(),
      if (_imageUrls.isNotEmpty) 'imageUrl': _imageUrls.first,
      'imageUrls': _imageUrls,
      'videoUrl': _videoUrl,
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
      'status': status,
    };
  }

  /// Creates the listing on first save, updates it on every save after
  /// that -- `_draftId` is how every other method knows which case it
  /// is. Returns the saved property's id (updating `_draftId` as a
  /// side effect) so callers don't have to duplicate that bookkeeping.
  Future<int?> _persist(Map<String, dynamic> payload) async {
    if (_draftId != null) {
      await ApiService.put('/api/properties/$_draftId', payload);
      return _draftId;
    }
    final result = await ApiService.post('/api/properties', payload);
    final newId = result is Map ? result['id'] as int? : null;
    if (newId != null) _draftId = newId;
    return _draftId;
  }

  /// Fires on every step advance so a listing exists as a draft on the
  /// server from partway through the wizard onward, not just when the
  /// user explicitly taps Save Draft or reaches the final Publish step.
  /// Deliberately silent and non-blocking: it must never interrupt or
  /// delay navigation between steps, and a failure here isn't the
  /// user's problem to see -- Save Draft and Publish still report
  /// their own errors normally, and either will simply retry the save
  /// next time it's called.
  void _autosaveDraft() async {
    // Nothing worth persisting yet on a completely untouched first step.
    if (_titleCtrl.text.trim().isEmpty && _imageUrls.isEmpty && !_isEditing) return;
    try {
      await _persist(_buildPayload(status: 'DRAFT'));
    } catch (_) {
      // Swallow silently -- see method doc. Explicit saves still surface
      // their own errors to the user.
    }
  }

  /// Landlords must have a verified phone before their first listing can
  /// go live -- checked here rather than earlier in the wizard so
  /// browsing/drafting the listing itself stays frictionless, matching
  /// the deferred-verification model already used for becoming a
  /// landlord in the first place. Returns false if the user backs out
  /// of verification, in which case publish should not proceed.
  Future<bool> _ensurePhoneVerified() async {
    try {
      final me = await ApiService.get('/api/users/me');
      if (me['phoneVerified'] == true) return true;
    } catch (_) {
      // If the check itself fails (network hiccup), fall through to the
      // verification screen rather than silently allowing an unverified
      // publish.
    }

    if (!mounted) return false;
    final verified = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PhoneVerificationPage()),
    );
    return verified == true;
  }

  Future<void> _submitProperty() async {
    if (!await _ensurePhoneVerified()) return;

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

    try {
      await _persist(_buildPayload(status: 'PUBLISHED'));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? 'Listing updated' : 'Property listed successfully!')),
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
    if (_step > 0 && !_isLoading) {
      setState(() {
        _movingForward = false;
        _step--;
      });
    }
  }

  /// Saves whatever's been filled in so far as a DRAFT and exits the
  /// wizard, without the phone-verification gate or required-field
  /// checks that publishing enforces -- a draft is allowed to be
  /// incomplete by definition. Available from any step, not just the
  /// final review screen, so closing the wizard early doesn't lose
  /// everything typed so far. Unlike _autosaveDraft, this is a visible,
  /// user-triggered action, so it does show success/failure feedback.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(_isEditing ? 'Edit Listing' : 'List a Property', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveDraft,
            child: Text('Save Draft', style: TextStyle(color: _isLoading ? Colors.white24 : Colors.white70)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Step Progress Indicator -- animates its fill so advancing
              // a step reads as forward motion rather than an instant
              // snap, matching the rest of the wizard's transitions.
              Row(
                children: List.generate(
                  5,
                  (idx) => Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
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

              // Step content slides in the direction of travel (right-to-
              // left advancing, left-to-right going back) with a fade,
              // instead of jump-cutting straight to the next step's
              // content -- this is the main thing that made the wizard
              // feel choppy rather than like a single guided flow.
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  transitionBuilder: (child, animation) {
                    final offsetTween = Tween<Offset>(
                      begin: Offset(_movingForward ? 0.08 : -0.08, 0),
                      end: Offset.zero,
                    );
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: animation.drive(offsetTween),
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

              const SizedBox(height: 16),

              Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _prevStep,
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
                      onPressed: _isLoading ? null : _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: Colors.white54,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54),
                            )
                          : Text(
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
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: Transform.scale(scale: 0.85 + (0.15 * value), child: child),
                    ),
                    child: Stack(
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
                    ),
                  );
                },
              ),
            ],

            const SizedBox(height: 28),
            const Divider(color: Colors.white12),
            const SizedBox(height: 12),
            const Text('Walkthrough Video (optional)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('A short vertical walkthrough helps renters picture the space', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            const SizedBox(height: 16),

            if (_uploadingVideo)
              Row(
                children: [
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Text('Uploading video...', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                ],
              )
            else if (_videoUrl != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF2C2C2E)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.videocam, color: Colors.white70),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Video attached', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                    GestureDetector(
                      onTap: _removeVideo,
                      child: const Icon(Icons.close, color: Colors.grey, size: 20),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickVideo(ImageSource.camera),
                      icon: const Icon(Icons.videocam_outlined, size: 18),
                      label: const Text('Record Video'),
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
                      onPressed: () => _pickVideo(ImageSource.gallery),
                      icon: const Icon(Icons.video_library_outlined, size: 18),
                      label: const Text('From Gallery'),
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
            TextField(
              controller: _buildingNameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Apartment / Building Name (optional)'),
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
