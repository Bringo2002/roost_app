import 'package:flutter/material.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/widgets/property/property_image.dart';
import 'package:roost_app/widgets/property/property_location.dart';
import 'package:roost_app/widgets/property/property_price.dart';

class PropertyCard extends StatelessWidget {
  const PropertyCard({
    super.key,
    required this.property,
    this.onTap,
    this.onFavoriteTap,
    this.isFavorite = false,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    this.showTopImage = true,
    this.compact = false,
  });

  final Property property;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;
  final bool isFavorite;
  final EdgeInsets margin;
  final bool showTopImage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[900],
      margin: margin,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showTopImage)
              PropertyImage(
                imageUrl: property.imageUrl,
                height: compact ? 140 : 180,
                overlay: _buildTopOverlay(),
              ),
            Padding(
              padding: EdgeInsets.all(compact ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _titleRow(),
                  SizedBox(height: compact ? 6 : 8),
                  PropertyLocation(
                    location: property.location,
                    compact: compact,
                  ),
                  SizedBox(height: compact ? 10 : 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: PropertyPrice(
                          amount: property.price,
                          fontSize: compact ? 16 : 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _typePill(property.type),
                    ],
                  ),
                  SizedBox(height: compact ? 8 : 10),
                  _metaRow(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopOverlay() {
    return Stack(
      children: [
        if (onFavoriteTap != null)
          Positioned(
            right: 10,
            top: 10,
            child: Material(
              color: Colors.black45,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onFavoriteTap,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        if (property.holdingFeePaid)
          Positioned(left: 10, top: 10, child: _badge('UNDER OFFER')),
      ],
    );
  }

  Widget _titleRow() {
    return Row(
      children: [
        Expanded(
          child: Text(
            property.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 16 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (property.verified) ...[
          const SizedBox(width: 6),
          const Icon(Icons.verified, color: Colors.white, size: 18),
        ],
        const SizedBox(width: 8),
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: property.available ? Colors.white : Colors.grey[700],
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  Widget _metaRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.bed_outlined, color: Colors.grey[600], size: 16),
            const SizedBox(width: 4),
            Text(
              '${property.bedrooms} bedroom${property.bedrooms == 1 ? '' : 's'}',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ],
        ),
        if (property.reviewCount > 0)
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 14),
              const SizedBox(width: 4),
              Text(
                '${property.averageRating.toStringAsFixed(1)} (${property.reviewCount})',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
      ],
    );
  }

  Widget _typePill(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[700]!),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        type.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white54),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
