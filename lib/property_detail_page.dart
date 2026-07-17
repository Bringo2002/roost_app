import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:roost_app/services/favorites_service.dart';
import 'package:roost_app/pages/chat_room_page.dart';
import 'package:video_player/video_player.dart';
import 'config.dart';

class PropertyDetailPage extends StatefulWidget {
  final Property property;

  const PropertyDetailPage({super.key, required this.property});

  @override
  State<PropertyDetailPage> createState() => _PropertyDetailPageState();
}

class _PropertyDetailPageState extends State<PropertyDetailPage> {
  late bool _holdingFeePaid;
  bool _isSecuring = false;
  bool _isFavorite = false;
  int _currentImageIndex = 0;
  List<dynamic> _reviews = [];
  double _averageRating = 0.0;
  int _reviewCount = 0;
  bool _loadingReviews = true;
  String _userRole = 'TENANT';
  String _mediaMode = 'photos'; // 'photos' or 'video'

  @override
  void initState() {
    super.initState();
    _holdingFeePaid = widget.property.holdingFeePaid;
    _checkIfFavorite();
    _loadReviews();
    _loadUserRole();
  }

  Future<void> _checkIfFavorite() async {
    if (widget.property.id != null) {
      final fav = await FavoritesService.isFavorite(widget.property.id!);
      setState(() {
        _isFavorite = fav;
      });
    }
  }

  Future<void> _loadReviews() async {
    if (widget.property.id == null) return;
    setState(() => _loadingReviews = true);
    try {
      final res = await ApiService.get('/api/reviews/property/${widget.property.id}');
      if (!mounted) return;
      setState(() {
        _reviews = res['reviews'] ?? [];
        _averageRating = (res['averageRating'] ?? 0.0).toDouble();
        _reviewCount = res['reviewCount'] ?? 0;
        _loadingReviews = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingReviews = false);
    }
  }

  Future<void> _loadUserRole() async {
    try {
      final user = await ApiService.get('/api/users/me');
      setState(() {
        _userRole = user['role'] ?? 'TENANT';
      });
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    if (widget.property.id != null) {
      await FavoritesService.toggle(widget.property.id!);
      _checkIfFavorite();
    }
  }

  Future<void> _showReviewDialog() async {
    int selectedRating = 5;
    final commentCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[950],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Add Review', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rating:', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (idx) {
                      final ratingValue = idx + 1;
                      return IconButton(
                        icon: Icon(
                          ratingValue <= selectedRating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 32,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            selectedRating = ratingValue;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: commentCtrl,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Share your experience...',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.grey[900],
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[800]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    try {
                      await ApiService.post('/api/reviews', {
                        'propertyId': widget.property.id,
                        'rating': selectedRating,
                        'comment': commentCtrl.text.trim(),
                      });
                      Navigator.pop(ctx);
                      if (!mounted) return;
                      _loadReviews();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed: $e')),
                      );
                    }
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
    commentCtrl.dispose();
  }

  Future<void> _showApplicationDialog() async {
    final formKey = GlobalKey<FormState>();
    String fullName = '';
    String nationalId = '';
    String employmentStatus = 'Employed';
    double monthlyIncome = 0.0;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[950],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Rental Application', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Full Name'),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        onSaved: (v) => fullName = v ?? '',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('National ID / Passport'),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        onSaved: (v) => nationalId = v ?? '',
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        dropdownColor: Colors.grey[900],
                        value: employmentStatus,
                        items: ['Employed', 'Self-Employed', 'Student', 'Unemployed'].map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(status, style: const TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setDialogState(() {
                            employmentStatus = v ?? 'Employed';
                          });
                        },
                        decoration: _inputDecoration('Employment Status'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Monthly Income (KES)'),
                        keyboardType: TextInputType.number,
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        onSaved: (v) => monthlyIncome = double.tryParse(v ?? '') ?? 0.0,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      formKey.currentState!.save();
                      try {
                        await ApiService.post('/api/applications', {
                          'propertyId': widget.property.id,
                          'fullName': fullName,
                          'nationalId': nationalId,
                          'employmentStatus': employmentStatus,
                          'monthlyIncome': monthlyIncome,
                        });
                        Navigator.pop(ctx);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Application submitted successfully!')),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: const Color(0x1AFFFFFF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[800]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white),
      ),
    );
  }

  Future<void> _showMpesaDialog() async {
    String phone = '';
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.grey[950],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Secure with M-Pesa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Pay KES 2,000 holding fee to secure this property.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration('M-Pesa Phone Number'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  onSaved: (v) => phone = v ?? '',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Pay Now'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      _processMpesaPayment(phone);
    }
  }

  Future<void> _processMpesaPayment(String phone) async {
    setState(() {
      _isSecuring = true;
    });

    try {
      await ApiService.post(
        '/api/verification/pay',
        {
          'propertyId': widget.property.id,
          'tenantPhone': phone,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Property Secured! Verification record created.')),
        );
        setState(() {
          _holdingFeePaid = true;
        });
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
          _isSecuring = false;
        });
      }
    }
  }

  /// Builds the hero media section at the top.
  Widget _buildHeroMedia() {
    final List<String> urls = [];
    if (widget.property.imageUrl != null && widget.property.imageUrl!.isNotEmpty) {
      urls.add(widget.property.imageUrl!);
    }
    for (final url in widget.property.imageUrls) {
      if (url.isNotEmpty && !urls.contains(url)) {
        urls.add(url);
      }
    }

    final hasVideo = widget.property.videoUrl != null && widget.property.videoUrl!.isNotEmpty;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Media content
        if (_mediaMode == 'video' && hasVideo)
          SizedBox(
            height: 320,
            width: double.infinity,
            child: PropertyVideoPlayer(videoUrl: widget.property.videoUrl!),
          )
        else if (urls.isEmpty)
          Container(
            height: 320,
            width: double.infinity,
            color: Colors.grey[900],
            child: Center(
              child: Icon(Icons.home_outlined, color: Colors.grey[800], size: 64),
            ),
          )
        else
          SizedBox(
            height: 320,
            child: Stack(
              children: [
                PageView.builder(
                  itemCount: urls.length,
                  onPageChanged: (idx) {
                    setState(() {
                      _currentImageIndex = idx;
                    });
                  },
                  itemBuilder: (context, idx) {
                    return CachedNetworkImage(
                      imageUrl: urls[idx],
                      height: 320,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 320,
                        color: Colors.grey[950],
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white24,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 320,
                        color: Colors.grey[950],
                        child: const Center(
                          child: Icon(Icons.broken_image, color: Colors.grey, size: 48),
                        ),
                      ),
                    );
                  },
                ),
                // Premium Slide Counter Badge
                if (urls.length > 1)
                  Positioned(
                    bottom: 24,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xB3000000),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_currentImageIndex + 1} / ${urls.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

        // Glassmorphic Media Selector Pill
        if (hasVideo)
          Positioned(
            bottom: 20,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xD9121212),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12, width: 0.5),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _mediaMode = 'photos'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _mediaMode == 'photos' ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.photo_library_rounded,
                            color: _mediaMode == 'photos' ? Colors.black : Colors.white60,
                            size: 13,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Photos',
                            style: TextStyle(
                              color: _mediaMode == 'photos' ? Colors.black : Colors.white60,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _mediaMode = 'video'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _mediaMode == 'video' ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.play_circle_fill_rounded,
                            color: _mediaMode == 'video' ? Colors.black : Colors.white60,
                            size: 13,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Walkthrough',
                            style: TextStyle(
                              color: _mediaMode == 'video' ? Colors.black : Colors.white60,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          // Media Header
          SliverAppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            expandedHeight: 320,
            pinned: true,
            actions: [
              if (widget.property.id != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0x40000000),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: _isFavorite ? Colors.red : Colors.white,
                      ),
                      onPressed: _toggleFavorite,
                    ),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeroMedia(),
            ),
          ),

          // Property details
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Verified Badge & Offer Status
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.property.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.location_on, color: Colors.grey[500], size: 14),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    widget.property.location,
                                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (widget.property.verified)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0x1F00C853),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.greenAccent, width: 0.5),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified, color: Colors.greenAccent, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'VERIFIED',
                                    style: TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (_holdingFeePaid) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0x33FF9800),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.orange, width: 0.5),
                              ),
                              child: const Text(
                                'UNDER OFFER',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Interactive Feature Grid
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildGridFeature(
                        icon: Icons.meeting_room_rounded,
                        title: '${widget.property.bedrooms} Bedrooms',
                        subtitle: 'Spacious layout',
                      ),
                      _buildGridFeature(
                        icon: Icons.local_activity_rounded,
                        title: widget.property.type.toUpperCase(),
                        subtitle: 'Property Type',
                      ),
                      _buildGridFeature(
                        icon: Icons.check_circle_rounded,
                        title: widget.property.available ? 'Ready Now' : 'Occupied',
                        subtitle: 'Availability',
                        color: widget.property.available ? Colors.greenAccent : Colors.redAccent,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 20),

                  // Pricing Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RENTAL PRICE',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'KES ${NumberFormat('#,##0').format(widget.property.price)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      if (_reviewCount > 0)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  _averageRating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$_reviewCount reviews',
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                            ),
                          ],
                        )
                      else
                        Text(
                          'No reviews yet',
                          style: TextStyle(color: Colors.grey[500], fontSize: 13),
                        ),
                    ],
                  ),

                  // Description
                  if (widget.property.description.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 20),
                    const Text(
                      'Overview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.property.description,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 20),

                  // Call to Actions
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _holdingFeePaid ? Colors.grey[900] : Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      icon: _isSecuring
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Icon(_holdingFeePaid ? Icons.lock_outline : Icons.flash_on_rounded),
                      onPressed: (_holdingFeePaid || _isSecuring) ? null : _showMpesaDialog,
                      label: Text(
                        _holdingFeePaid ? 'Under Offer (Holding Fee Paid)' : 'Instant Secure via M-Pesa',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () {
                              if (widget.property.owner != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatRoomPage(partner: widget.property.owner!),
                                  ),
                                );
                              } else {
                                final phone = widget.property.landlordPhone;
                                if (phone.isNotEmpty) {
                                  final uri = Uri.parse('tel:$phone');
                                  canLaunchUrl(uri).then((canLaunch) {
                                    if (canLaunch) launchUrl(uri);
                                  });
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Landlord contact info not available')),
                                  );
                                }
                              }
                            },
                            child: const Text(
                              'Message Landlord',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ),
                      if (_userRole == 'TENANT') ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0x15FFFFFF),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: const BorderSide(color: Colors.white10),
                                ),
                              ),
                              onPressed: _showApplicationDialog,
                              child: const Text(
                                'Apply to Rent',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 20),

                  // Reviews
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tenant Reviews',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (_userRole == 'TENANT')
                        TextButton.icon(
                          onPressed: _showReviewDialog,
                          icon: const Icon(Icons.rate_review_rounded, size: 16, color: Colors.white),
                          label: const Text(
                            'Write a Review',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _loadingReviews
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : _reviews.isEmpty
                          ? Text(
                              'No reviews yet. Be the first to review this property!',
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            )
                          : ListView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: _reviews.length,
                              itemBuilder: (context, index) {
                                final r = _reviews[index];
                                final reviewerName = r['reviewer']?['name'] ?? 'Tenant';
                                final rating = r['rating'] ?? 0;
                                final comment = r['comment'] ?? '';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0x0DFFFFFF),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white10, width: 0.5),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            reviewerName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Row(
                                            children: List.generate(5, (idx) {
                                              return Icon(
                                                idx < rating ? Icons.star : Icons.star_border,
                                                color: Colors.amber,
                                                size: 12,
                                              );
                                            }),
                                          ),
                                        ],
                                      ),
                                      if (comment.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          comment,
                                          style: TextStyle(
                                            color: Colors.grey[300],
                                            fontSize: 13,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridFeature({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? color,
  }) {
    return Container(
      width: (MediaQuery.of(context).size.width - 56) / 3,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x0BFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color ?? Colors.white70, size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class PropertyVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const PropertyVideoPlayer({super.key, required this.videoUrl});

  @override
  State<PropertyVideoPlayer> createState() => _PropertyVideoPlayerState();
}

class _PropertyVideoPlayerState extends State<PropertyVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() {
          _initialized = true;
        });
        _controller.play();
        _controller.setLooping(true);
      }).catchError((_) {
        setState(() {
          _hasError = true;
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Colors.grey[950],
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.video_camera_back_outlined, color: Colors.grey, size: 40),
              SizedBox(height: 8),
              Text('Unable to play video walkthrough', style: TextStyle(color: Colors.white54, fontSize: 13)),
            ],
          ),
        ),
      );
    }
    if (!_initialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      );
    }
    return GestureDetector(
      onTap: () {
        setState(() {
          _controller.value.isPlaying ? _controller.pause() : _controller.play();
        });
      },
      child: Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller.value.size.width,
              height: _controller.value.size.height,
              child: VideoPlayer(_controller),
            ),
          ),
          if (!_controller.value.isPlaying)
            Container(
              decoration: const BoxDecoration(
                color: Colors.black38,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(12),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
            ),
          Positioned(
            bottom: 60, // Positioned above the media selector pill
            right: 16,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _controller.value.volume == 0.0 ? _controller.setVolume(1.0) : _controller.setVolume(0.0);
                });
              },
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xCC000000),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(8),
                child: Icon(
                  _controller.value.volume == 0.0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
