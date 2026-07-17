import 'package:flutter/material.dart';
import 'package:roost_app/services/api_service.dart';

import 'package:latlong2/latlong.dart';
import 'package:roost_app/pages/search/location_picker_page.dart';

class AddPropertyPage extends StatefulWidget {
  const AddPropertyPage({super.key});

  @override
  State<AddPropertyPage> createState() => _AddPropertyPageState();
}

class _AddPropertyPageState extends State<AddPropertyPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  String _title = '';
  String _location = '';
  double _price = 0;
  int _bedrooms = 1;
  String _type = 'rental';
  String _landlordPhone = '';
  String _description = '';
  String _imageUrl = '';
  List<String> _imageUrls = [];
  final _imageUrlCtrl = TextEditingController();
  String _videoUrl = '';
  double? _latitude;
  double? _longitude;

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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
    });

    try {
      await ApiService.post(
        '/api/properties',
        {
          'title': _title,
          'location': _location,
          'price': _price,
          'bedrooms': _bedrooms,
          'type': _type,
          'available': true,
          'landlordPhone': _landlordPhone,
          'description': _description,
          'imageUrl': _imageUrl,
          'imageUrls': _imageUrls,
          'videoUrl': _videoUrl,
          'latitude': _latitude,
          'longitude': _longitude,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Property added successfully!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Add Property', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTextField(
                      label: 'Title (e.g. Modern Apartment)',
                      onSaved: (v) => _title = v ?? '',
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Location (e.g. Westlands)',
                      onSaved: (v) => _location = v ?? '',
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            label: 'Price (KES)',
                            keyboardType: TextInputType.number,
                            onSaved: (v) => _price = double.tryParse(v ?? '0') ?? 0,
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            label: 'Bedrooms',
                            keyboardType: TextInputType.number,
                            onSaved: (v) => _bedrooms = int.tryParse(v ?? '1') ?? 1,
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _type,
                      dropdownColor: Colors.grey[900],
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Property Type'),
                      items: const [
                        DropdownMenuItem(value: 'rental', child: Text('Rental')),
                        DropdownMenuItem(value: 'sale', child: Text('Sale')),
                        DropdownMenuItem(value: 'airbnb', child: Text('Airbnb')),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _type = val ?? 'rental';
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Landlord Phone (e.g. +2547...)',
                      keyboardType: TextInputType.phone,
                      onSaved: (v) => _landlordPhone = v ?? '',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Primary Image URL (optional)',
                      keyboardType: TextInputType.url,
                      onSaved: (v) => _imageUrl = v ?? '',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _imageUrlCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Additional Image URL'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.white, size: 36),
                          onPressed: () {
                            final url = _imageUrlCtrl.text.trim();
                            if (url.isNotEmpty) {
                              setState(() {
                                _imageUrls.add(url);
                                _imageUrlCtrl.clear();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    if (_imageUrls.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _imageUrls.map((url) {
                          return Chip(
                            backgroundColor: Colors.grey[900],
                            labelStyle: const TextStyle(color: Colors.white),
                            label: Text(
                              url.length > 25 ? '${url.substring(0, 25)}...' : url,
                              style: const TextStyle(fontSize: 12),
                            ),
                            deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white54),
                            onDeleted: () {
                              setState(() {
                                _imageUrls.remove(url);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Walkthrough Video URL (optional)',
                      keyboardType: TextInputType.url,
                      onSaved: (v) => _videoUrl = v ?? '',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Description',
                      maxLines: 4,
                      onSaved: (v) => _description = v ?? '',
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      tileColor: Colors.grey[900],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: const Icon(Icons.map_outlined, color: Colors.white),
                      title: Text(
                        _latitude != null && _longitude != null
                            ? 'Map Location: Pinned (${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)})'
                            : 'Set Map Location (optional)',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                      onTap: _pickLocation,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _submitForm,
                      child: const Text(
                        'Submit Property',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required String label,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    void Function(String?)? onSaved,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: _inputDecoration(label),
      validator: validator,
      onSaved: onSaved,
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[400]),
      filled: true,
      fillColor: Colors.grey[900],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white38),
      ),
    );
  }
}
