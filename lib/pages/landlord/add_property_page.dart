import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/pages/profile/phone_verification_page.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/location_service.dart';
import 'package:roost_app/widgets/property/property_card.dart';

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

  // True once the server has recorded this location as GPS-confirmed
  // on-site (via /verify-gps). Separate from _locationConfirmed, which
  // only means "we captured coordinates" -- this tracks whether that
  // capture was successfully recorded server-side toward the badge.
  bool _gpsVerified = false;
  bool _checkingGps = false;

  bool _furnished = false;
  bool _parking = false;
  bool _wifi = false;
  bool _water = true;
  bool _security = true;
  bool _balcony = false;
  bool _petFriendly = false;

  static const int _minPhotos = 3;
  static const List<String> _stepLabels = ['Photos', 'Basics', 'Location', 'Amenities', 'Contact', 'Review'];

  /// Field-level validation errors for the *current* step, keyed by field
  /// name. Populated by _validateStep when advancing fails, and cleared
  /// per-field as the user edits it -- shown inline under the offending
  /// field instead of a SnackBar the user has to remember and go hunting
  /// for the cause of.
  final Map<String, String> _errors = {};

  void _clearError(String key) {
    if (_errors.containsKey(key)) setState(() => _errors.remove(key));
  }

  /// Validates only the fields belonging to [step], populating _errors
  /// with anything wrong. Returns true if that step is complete.
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
        final bedrooms = int.tryParse(_bedroomsCtrl.text.trim());
        if (_bedroomsCtrl.text.trim().isEmpty || bedrooms == null || bedrooms < 0) {
          errors['bedrooms'] = 'Enter a valid number';
        }
        final bathrooms = int.tryParse(_bathroomsCtrl.text.trim());
        if (_bathroomsCtrl.text.trim().isEmpty || bathrooms == null || bathrooms < 0) {
          errors['bathrooms'] = 'Enter a valid number';
        }
        break;
      case 2:
        if (_locationCtrl.text.trim().isEmpty) {
          errors['locationText'] = 'Add a neighborhood or street';
        }
        if (!_locationConfirmed) {
          errors['gps'] = "Use your current location to continue -- see above";
        }
        break;
      case 3:
        break; // Amenities are all optional toggles.
      case 4:
        if (_phoneCtrl.text.trim().isEmpty) {
          errors['phone'] = 'Add a contact phone number';
        }
        break;
    }
    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
    });
    return errors.isEmpty;
  }
  static const int _maxPhotos = 10;
  final List<String> _imageUrls = [];
  String? _videoUrl;
  final ImagePicker _picker = ImagePicker();
  bool _uploadingPhotos = false;
  int _uploadDone = 0;
  int _uploadTotal = 0;
  bool _uploadingVideo = false;

  bool get _isEditing => widget.editingProperty != null;

  /// Guards against a second autosave firing (and racing to POST a
  /// duplicate draft) while the first is still in flight -- see
  /// _autosaveDraft.
  bool _autosaving = false;

  /// Single source of truth for "don't let the user move on right now" --
  /// covers final submit/save-draft AND active photo/video uploads AND
  /// an in-flight autosave, so Next/Back/Save Draft can't be tapped into
  /// an inconsistent mid-upload or mid-save state.
  bool get _busy => _isLoading || _uploadingPhotos || _uploadingVideo || _autosaving;

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
    _gpsVerified = p.gpsVerified;

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

  /// Captures the property's location directly from the device's live
  /// GPS -- there is no manual pin-dropping anywhere in this flow, so the
  /// coordinates saved here are, by construction, wherever the landlord
  /// is actually standing. That's also what /verify-gps is checking, so
  /// this immediately records server-side GPS verification too, rather
  /// than treating capture and verification as two separate steps.
  Future<void> _captureLocation() async {
    if (_checkingGps) return;
    setState(() => _checkingGps = true);
    try {
      final position = await LocationService.getCurrentPosition();
      if (position == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't get your location. Make sure location access is allowed for Roost, then try again.")),
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationConfirmed = true;
        // Reset first -- if this capture's server verification below
        // fails, we must not keep showing "verified" from a previous,
        // now-superseded capture.
        _gpsVerified = false;
      });

      // Best-effort: coordinates are already captured and usable even if
      // this part fails (flaky network, etc). The Verified badge just
      // won't show until it succeeds -- retryable via "Update Location".
      try {
        final status = _isEditing ? widget.editingProperty!.status : 'DRAFT';
        final id = await _persist(_buildPayload(status: status));
        if (id != null) {
          await ApiService.post('/api/properties/$id/verify-gps', {
            'latitude': position.latitude,
            'longitude': position.longitude,
          });
          if (mounted) setState(() => _gpsVerified = true);
        }
      } catch (_) {
        // Swallowed -- see doc comment above.
      }
    } finally {
      if (mounted) setState(() => _checkingGps = false);
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

  /// Builds an in-memory Property from the wizard's current field values,
  /// purely for rendering the real PropertyCard on the Review step --
  /// never sent anywhere. Field mapping deliberately mirrors
  /// _buildPayload exactly, so what's previewed matches what actually
  /// gets saved.
  Property _buildPreviewProperty() {
    return Property(
      title: _titleCtrl.text.trim(),
      buildingName: _buildingNameCtrl.text.trim().isEmpty ? null : _buildingNameCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
      location: _locationCtrl.text.trim(),
      price: double.tryParse(_priceCtrl.text.trim()) ?? 0.0,
      bedrooms: int.tryParse(_bedroomsCtrl.text.trim()) ?? 1,
      bathrooms: int.tryParse(_bathroomsCtrl.text.trim()) ?? 1,
      type: 'RENTAL',
      houseType: _houseType,
      landlordPhone: _phoneCtrl.text.trim(),
      available: _isEditing ? widget.editingProperty!.available : true,
      verified: _isEditing ? widget.editingProperty!.verified : false,
      gpsVerified: _gpsVerified,
      imageUrl: _imageUrls.isNotEmpty ? _imageUrls.first : null,
      imageUrls: _imageUrls,
      videoUrl: _videoUrl,
      latitude: _latitude,
      longitude: _longitude,
      furnished: _furnished,
      parking: _parking,
      water: _water,
      wifi: _wifi,
      security: _security,
      balcony: _balcony,
      petFriendly: _petFriendly,
      deposit: _depositCtrl.text.trim().isEmpty ? null : _depositCtrl.text.trim(),
      moveInDate: _moveInDate,
      country: CountryService.config.code,
    );
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
    // Already saving -- skip rather than fire a second concurrent POST,
    // which would race the first and create a duplicate draft before
    // _draftId gets set (see _persist).
    if (_autosaving) return;
    if (mounted) setState(() => _autosaving = true);
    try {
      await _persist(_buildPayload(status: 'DRAFT'));
    } catch (_) {
      // Swallow silently -- see method doc. Explicit saves still surface
      // their own errors to the user.
    } finally {
      if (mounted) setState(() => _autosaving = false);
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
    // Defense in depth: every step's fields were already validated on the
    // way through to reach Review, but re-check here too in case this
    // gets reached via some other path in the future.
    for (var s = 0; s <= 4; s++) {
      if (!_validateStep(s)) {
        if (!mounted) return;
        setState(() => _step = s);
        return;
      }
    }

    if (!await _ensurePhoneVerified()) return;

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
    if (_busy) return;
    final lastFieldStep = _stepLabels.length - 2; // last data-entry step, before Review
    if (_step <= lastFieldStep && !_validateStep(_step)) return;

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
      setState(() {
        _movingForward = false;
        _step--;
      });
    }
  }

  /// Used by the Review step's "Edit" links to jump straight back to a
  /// specific earlier step, rather than only being able to go back one
  /// step at a time.
  void _jumpToStep(int step) {
    if (_busy) return;
    setState(() {
      _movingForward = false;
      _step = step;
    });
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
            onPressed: _busy ? null : _saveDraft,
            child: Text('Save Draft', style: TextStyle(color: _busy ? Colors.white24 : Colors.white70)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Tells the user where they are in the journey by name, not
              // just an abstract fraction -- "Step 3 of 5 · Location"
              // instead of five unlabeled bars they have to decode.
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'STEP ${_step + 1} OF ${_stepLabels.length} · ${_stepLabels[_step].toUpperCase()}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Step Progress Indicator -- animates its fill so advancing
              // a step reads as forward motion rather than an instant
              // snap, matching the rest of the wizard's transitions.
              Row(
                children: List.generate(
                  _stepLabels.length,
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
                        onPressed: _busy ? null : _prevStep,
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
                      onPressed: _busy ? null : _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: Colors.white54,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54),
                            )
                          : Text(
                              _step == _stepLabels.length - 1 ? (_isEditing ? 'Save Changes' : 'Publish Listing') : 'Next Step',
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
        final hasMinPhotos = _imageUrls.length >= _minPhotos;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Property Photos', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Add high quality photos to attract renters', style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 12),

            // Status as a pill, not bare colored text -- scannable at a
            // glance, and the icon reinforces the color for anyone who
            // can't easily distinguish amber from green.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (hasMinPhotos ? Colors.greenAccent : Colors.amber).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasMinPhotos ? Icons.check_circle : Icons.info_outline,
                    size: 14,
                    color: hasMinPhotos ? Colors.greenAccent : Colors.amber,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    hasMinPhotos
                        ? '${_imageUrls.length} of $_minPhotos minimum photos added'
                        : '${_imageUrls.length} of $_minPhotos minimum photos added -- add ${_minPhotos - _imageUrls.length} more',
                    style: TextStyle(
                      color: hasMinPhotos ? Colors.greenAccent : Colors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Explains the "Cover" badge *before* it appears, rather than
            // leaving the user to notice and infer it after the fact.
            Row(
              children: [
                Icon(Icons.info_outline, size: 13, color: Colors.grey[600]),
                const SizedBox(width: 5),
                Text(
                  'Your first photo becomes the cover image',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
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
            if (_imageUrls.isEmpty && !_uploadingPhotos) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF2C2C2E), width: 1.2),
                ),
                child: Column(
                  children: [
                    Icon(Icons.add_a_photo_outlined, color: Colors.grey[600], size: 28),
                    const SizedBox(height: 12),
                    const Text(
                      'No photos yet',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Natural light and landscape shots of each room\nusually get the most views',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
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
              decoration: _inputDecoration('Listing Title (e.g. Modern 2BR Kilimani)', errorText: _errors['title']),
              onChanged: (_) => _clearError('title'),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Monthly Rent (${CountryService.config.currencyCode})', errorText: _errors['price']),
                    onChanged: (_) => _clearError('price'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _depositCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Deposit Terms (optional)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _bedroomsCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Bedrooms', errorText: _errors['bedrooms']),
                    onChanged: (_) => _clearError('bedrooms'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _bathroomsCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Bathrooms', errorText: _errors['bathrooms']),
                    onChanged: (_) => _clearError('bathrooms'),
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
            Text('Specify district & confirm your exact GPS location', style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 20),
            TextField(
              controller: _locationCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Location (e.g. Kilimani, Chania Avenue)', errorText: _errors['locationText']),
              onChanged: (_) => _clearError('locationText'),
            ),
            const SizedBox(height: 20),
            if (!_locationConfirmed)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _errors.containsKey('gps')
                        ? Colors.redAccent.withValues(alpha: 0.7)
                        : Colors.amber.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.my_location,
                      color: _errors.containsKey('gps') ? Colors.redAccent : Colors.amber,
                      size: 28,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "We'll use your device's GPS to pin this property",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "You'll need to be standing at the property -- this is what earns the Verified badge, so listings can't fake a location.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12.5, height: 1.4),
                    ),
                    if (_errors.containsKey('gps')) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Required to continue',
                        style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _checkingGps ? null : _captureLocation,
                        icon: _checkingGps
                            ? const SizedBox(
                                width: 14, height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54),
                              )
                            : const Icon(Icons.my_location, size: 16),
                        label: Text(_checkingGps ? 'Getting your location...' : 'Use My Current Location'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (_gpsVerified ? Colors.greenAccent : Colors.white).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _gpsVerified ? Colors.greenAccent.withValues(alpha: 0.4) : Colors.white24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _gpsVerified ? Icons.verified : Icons.location_on,
                          color: _gpsVerified ? Colors.greenAccent : Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _gpsVerified ? "Confirmed -- you're at this location" : 'Location captured',
                            style: TextStyle(
                              color: _gpsVerified ? Colors.greenAccent : Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    if (_gpsVerified) ...[
                      const SizedBox(height: 2),
                      Text(
                        'This counts toward your Verified badge',
                        style: TextStyle(color: Colors.greenAccent.withValues(alpha: 0.7), fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _checkingGps ? null : _captureLocation,
                      child: Text(
                        _checkingGps ? 'Updating...' : 'Update Location',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
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
              decoration: _inputDecoration('Contact Phone (e.g. +254 712 345 678)', errorText: _errors['phone']),
              onChanged: (_) => _clearError('phone'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionCtrl,
              maxLines: 4,
              maxLength: 500,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Description (optional, max 500 chars)'),
            ),
          ],
        );

      case 5:
      default:
        final amenityLabels = <String>[
          if (_furnished) 'Furnished',
          if (_parking) 'Parking',
          if (_wifi) 'WiFi',
          if (_water) '24hr Water',
          if (_security) 'Security',
          if (_balcony) 'Balcony',
          if (_petFriendly) 'Pet Friendly',
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Review Your Listing', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Check everything looks right before you publish', style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 16),
            Text(
              'PREVIEW -- THIS IS HOW YOUR LISTING WILL LOOK',
              style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
            ),
            const SizedBox(height: 10),
            // Renders the actual card widget used everywhere else in the
            // app, fed with the wizard's current values -- so this is a
            // real preview, not a text description of one. Wrapped in
            // IgnorePointer because the real card has live Call/Chat/
            // Navigate actions that assume a saved listing with a real
            // owner attached; this one doesn't have either yet.
            IgnorePointer(
              child: PropertyCard(
                property: _buildPreviewProperty(),
                margin: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 24),
            _ReviewSection(
              title: 'Photos',
              onEdit: () => _jumpToStep(0),
              lines: ['${_imageUrls.length} photo${_imageUrls.length == 1 ? '' : 's'} added'],
            ),
            _ReviewSection(
              title: 'Basics',
              onEdit: () => _jumpToStep(1),
              lines: [
                _titleCtrl.text.trim().isEmpty ? '(no title)' : _titleCtrl.text.trim(),
                '$_houseType · ${CountryService.pricePerMonth(double.tryParse(_priceCtrl.text.trim()) ?? 0)}',
                '${_bedroomsCtrl.text.trim()} bed · ${_bathroomsCtrl.text.trim()} bath'
                    '${_depositCtrl.text.trim().isEmpty ? '' : ' · Deposit: ${_depositCtrl.text.trim()}'}',
              ],
            ),
            _ReviewSection(
              title: 'Location',
              onEdit: () => _jumpToStep(2),
              lines: [
                _locationCtrl.text.trim().isEmpty ? '(no location)' : _locationCtrl.text.trim(),
              ],
              trailingIcon: _gpsVerified ? Icons.verified : Icons.info_outline,
              trailingIconColor: _gpsVerified ? Colors.greenAccent : Colors.amber,
              trailingLabel: _gpsVerified ? 'GPS-confirmed' : 'Not GPS-confirmed yet',
            ),
            _ReviewSection(
              title: 'Amenities',
              onEdit: () => _jumpToStep(3),
              lines: [amenityLabels.isEmpty ? 'None selected' : amenityLabels.join(' · ')],
            ),
            _ReviewSection(
              title: 'Contact',
              onEdit: () => _jumpToStep(4),
              lines: [
                _phoneCtrl.text.trim().isEmpty ? '(no phone)' : _phoneCtrl.text.trim(),
                if (_descriptionCtrl.text.trim().isNotEmpty)
                  _descriptionCtrl.text.trim().length > 80
                      ? '${_descriptionCtrl.text.trim().substring(0, 80)}...'
                      : _descriptionCtrl.text.trim(),
              ],
            ),
          ],
        );
    }
  }

  InputDecoration _inputDecoration(String label, {String? errorText}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[500]),
      filled: true,
      fillColor: const Color(0xFF1C1C1E),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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

/// A single editable summary card on the Review step -- a title, an
/// "Edit" link that jumps back to the step it summarizes, and a few
/// lines of plain-text content. Used identically for every section so
/// Review reads as one consistent list, not five differently-styled
/// blocks.
class _ReviewSection extends StatelessWidget {
  const _ReviewSection({
    required this.title,
    required this.onEdit,
    required this.lines,
    this.trailingIcon,
    this.trailingIconColor,
    this.trailingLabel,
  });

  final String title;
  final VoidCallback onEdit;
  final List<String> lines;
  final IconData? trailingIcon;
  final Color? trailingIconColor;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              GestureDetector(
                onTap: onEdit,
                child: const Text(
                  'Edit',
                  style: TextStyle(color: Colors.white70, fontSize: 12, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(line, style: TextStyle(color: Colors.grey[300], fontSize: 13, height: 1.4)),
            ),
          if (trailingIcon != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(trailingIcon, size: 14, color: trailingIconColor),
                const SizedBox(width: 6),
                Text(trailingLabel ?? '', style: TextStyle(color: trailingIconColor, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
