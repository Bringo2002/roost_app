import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:roost_app/services/favorites_service.dart';
import 'package:roost_app/pages/chat_room_page.dart';
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
              backgroundColor: Colors.grey[900],
              title: const Text('Add Review', style: TextStyle(color: Colors.white)),
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
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[800]!)),
                      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
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
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
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
              backgroundColor: Colors.grey[900],
              title: const Text('Rental Application', style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Full Name', labelStyle: TextStyle(color: Colors.white70)),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        onSaved: (v) => fullName = v ?? '',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'National ID / Passport', labelStyle: TextStyle(color: Colors.white70)),
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
                        decoration: const InputDecoration(labelText: 'Employment Status', labelStyle: TextStyle(color: Colors.white70)),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Monthly Income (KES)', labelStyle: TextStyle(color: Colors.white70)),
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
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
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

  Future<void> _showMpesaDialog() async {
    String phone = '';
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Secure with M-Pesa', style: TextStyle(color: Colors.white)),
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
                  decoration: InputDecoration(
                    labelText: 'M-Pesa Phone Number',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                  ),
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

  /// Builds the hero image section at the top of the detail page.
  Widget _buildHeroImage() {
    final List<String> urls = [];
    if (widget.property.imageUrl != null && widget.property.imageUrl!.isNotEmpty) {
      urls.add(widget.property.imageUrl!);
    }
    for (final url in widget.property.imageUrls) {
      if (url.isNotEmpty && !urls.contains(url)) {
        urls.add(url);
      }
    }

    Widget content;
    if (urls.isEmpty) {
      content = Container(
        height: 260,
        width: double.infinity,
        color: Colors.grey[850],
        child: Center(
          child: Icon(Icons.home_outlined, color: Colors.grey[700], size: 64),
        ),
      );
    } else {
      content = Stack(
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
                height: 260,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 260,
                  color: Colors.grey[850],
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white24,
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 260,
                  color: Colors.grey[850],
                  child: const Center(
                    child: Icon(Icons.broken_image, color: Colors.grey, size: 48),
                  ),
                ),
              );
            },
          ),
          if (urls.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(urls.length, (idx) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentImageIndex == idx ? Colors.white : Colors.white24,
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
            ),
        ],
      );
    }

    return Hero(
      tag: 'property-image-${widget.property.id}',
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
        child: SizedBox(
          height: 260,
          child: content,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          // Collapsible app bar with hero image
          SliverAppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            expandedHeight: 260,
            pinned: true,
            actions: [
              if (widget.property.id != null)
                IconButton(
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: Colors.white,
                  ),
                  onPressed: _toggleFavorite,
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeroImage(),
            ),
          ),

          // Property details content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // title
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.property.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (widget.property.verified)
                        const Tooltip(
                          message: 'Verified Listing',
                          child: Icon(Icons.verified, color: Colors.blue, size: 28),
                        ),
                      if (widget.property.holdingFeePaid) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: const Text('UNDER OFFER', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 8),
                  if (_reviewCount > 0)
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '${_averageRating.toStringAsFixed(1)} ($_reviewCount reviews)',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  else
                    const Row(
                      children: [
                        Icon(Icons.star_border, color: Colors.white24, size: 20),
                        SizedBox(width: 4),
                        Text(
                          'No reviews yet',
                          style: TextStyle(
                            color: Colors.white24,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 12),

                  // location
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.grey, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        widget.property.location,
                        style: TextStyle(color: Colors.grey[400], fontSize: 15),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // price
                  Text(
                    'KES ${NumberFormat('#,##0').format(widget.property.price)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // type chip + bedrooms
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.property.type.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.bed, color: Colors.grey[400], size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.property.bedrooms} bedroom',
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // availability
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: widget.property.available ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.property.available ? 'Available now' : 'Not available',
                        style: TextStyle(
                          color: widget.property.available ? Colors.green : Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  // description (if present)
                  if (widget.property.description.isNotEmpty) ...[
                    const Divider(color: Colors.grey, height: 40),
                    const Text(
                      'Description',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
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

                  const Divider(color: Colors.grey, height: 40),

                  // M-PESA Secure Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _holdingFeePaid ? Colors.grey[800] : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isSecuring 
                          ? const SizedBox(
                              width: 20, 
                              height: 20, 
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            )
                          : Icon(_holdingFeePaid ? Icons.lock : Icons.payments),
                      onPressed: (_holdingFeePaid || _isSecuring) ? null : _showMpesaDialog,
                      label: Text(
                        _holdingFeePaid ? 'Under Offer (Holding Fee Paid)' : 'Secure via M-Pesa',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // contact button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
                          // Fallback to phone if owner not available
                          final phone = widget.property.landlordPhone;
                          if (phone.isNotEmpty) {
                            final uri = Uri.parse('tel:$phone');
                            canLaunchUrl(uri).then((canLaunch) {
                              if (canLaunch) {
                                launchUrl(uri);
                              }
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
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  if (_userRole == 'TENANT') ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white10,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Colors.white24),
                          ),
                        ),
                        onPressed: _showApplicationDialog,
                        child: const Text(
                          'Apply to Rent',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],

                  const Divider(color: Colors.grey, height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Reviews',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_userRole == 'TENANT')
                        TextButton.icon(
                          onPressed: _showReviewDialog,
                          icon: const Icon(Icons.add, size: 18, color: Colors.white),
                          label: const Text('Add Review', style: TextStyle(color: Colors.white)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _loadingReviews
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : _reviews.isEmpty
                          ? const Text(
                              'No reviews yet. Be the first to review!',
                              style: TextStyle(color: Colors.white30, fontSize: 14),
                            )
                          : ListView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: _reviews.length,
                              itemBuilder: (context, index) {
                                final r = _reviews[index];
                                final reviewerName = r['reviewer']?['name'] ?? 'User';
                                final rating = r['rating'] ?? 0;
                                final comment = r['comment'] ?? '';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
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
                                              fontSize: 14,
                                            ),
                                          ),
                                          Row(
                                            children: List.generate(5, (idx) {
                                              return Icon(
                                                idx < rating ? Icons.star : Icons.star_border,
                                                color: Colors.amber,
                                                size: 14,
                                              );
                                            }),
                                          ),
                                        ],
                                      ),
                                      if (comment.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          comment,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),

                  // Bottom padding for scroll clearance
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
