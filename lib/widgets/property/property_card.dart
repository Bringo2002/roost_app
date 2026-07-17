import 'package:flutter/material.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/theme/app_text_styles.dart';
import 'package:roost_app/theme/app_theme.dart';
import 'package:roost_app/widgets/property/property_image.dart';
import 'package:roost_app/widgets/property/property_location.dart';
import 'package:roost_app/widgets/property/property_price.dart';

/// The primary listing card used across search results, saved properties,
/// and landlord dashboards. Premium black & white styling, driven entirely
/// by AppColors / AppTextStyles / AppTheme tokens.
class PropertyCard extends StatefulWidget {
  const PropertyCard({
    super.key,
    required this.property,
    this.onTap,
    this.onFavoriteTap,
    this.isFavorite = false,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    this.showTopImage = true,
    this.compact = false,
    this.heroTag,
  });

  final Property property;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;
  final bool isFavorite;
  final EdgeInsets margin;
  final bool showTopImage;
  final bool compact;

  /// Optional Hero tag for a shared-element transition into the detail
  /// page. Callers pass e.g. `'property-image-${property.id}'`.
  final Object? heroTag;

  @override
  State<PropertyCard> createState() => _PropertyCardState();
}

class _PropertyCardState extends State<PropertyCard> {
  bool _pressed = false;
  bool _hovered = false;

  Property get property => widget.property;

  List<String> get _galleryUrls {
    final urls = <String>[];
    if (property.imageUrl != null && property.imageUrl!.trim().isNotEmpty) {
      urls.add(property.imageUrl!);
    }
    for (final url in property.imageUrls) {
      if (url.trim().isNotEmpty && !urls.contains(url)) {
        urls.add(url);
      }
    }
    return urls;
  }

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.98 : 1.0;
    final lift = _hovered && !_pressed ? -2.0 : 0.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          margin: widget.margin,
          transform: Matrix4.identity()
            ..translateByDouble(0.0, lift, 0.0, 1.0)
            ..scaleByDouble(scale, scale, scale, 1.0),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(AppRadii.card),
            boxShadow: _hovered ? _elevatedShadow : AppShadows.card,
            border: Border.all(color: AppColors.divider, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showTopImage) _buildImage(),
              Padding(
                padding: EdgeInsets.all(widget.compact ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TitleRow(property: property, compact: widget.compact),
                    SizedBox(height: widget.compact ? 6 : 8),
                    PropertyLocation(
                      location: property.location,
                      compact: widget.compact,
                    ),
                    SizedBox(height: widget.compact ? 10 : 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: PropertyPrice(
                            amount: property.price,
                            compact: widget.compact,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _TypeChip(label: property.type),
                      ],
                    ),
                    SizedBox(height: widget.compact ? 8 : 10),
                    _AttributeRow(property: property),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<BoxShadow> get _elevatedShadow => [
    BoxShadow(
      color: AppColors.shadow,
      blurRadius: 28,
      offset: const Offset(0, 14),
    ),
  ];

  Widget _buildImage() {
    return PropertyImage(
      imageUrls: _galleryUrls,
      height: widget.compact ? 140 : 180,
      heroTag: widget.heroTag,
      topRight: widget.onFavoriteTap != null
          ? _FavoriteButton(
              isFavorite: widget.isFavorite,
              onTap: widget.onFavoriteTap!,
            )
          : null,
      topLeft: property.holdingFeePaid
          ? const _StatusBadge(label: 'UNDER OFFER')
          : null,
    );
  }
}

/// Circular, semi-transparent favorite toggle with a 48x48 touch target.
class _FavoriteButton extends StatefulWidget {
  const _FavoriteButton({required this.isFavorite, required this.onTap});

  final bool isFavorite;
  final VoidCallback onTap;

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    lowerBound: 0.9,
    upperBound: 1.0,
    value: 1.0,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    await _controller.reverse();
    await _controller.forward();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.isFavorite ? 'Remove from favorites' : 'Add to favorites',
      child: SizedBox(
        width: 48,
        height: 48,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _handleTap,
            child: Center(
              child: ScaleTransition(
                scale: _controller,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.scrimDark,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: AppColors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.scrimDark,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: AppTextStyles.chipLabel),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.chipLabel.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.property, required this.compact});

  final Property property;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            property.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.title.copyWith(
              fontSize: compact ? 15 : 16,
            ),
          ),
        ),
        if (property.verified) ...[
          const SizedBox(width: 6),
          const Icon(Icons.verified, color: AppColors.white, size: 16),
        ],
        const SizedBox(width: 8),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: property.available ? AppColors.white : AppColors.grey700,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

/// Bedrooms + rating, the only two attribute fields the Property model
/// currently supports. Bathrooms / square footage will slot in here once
/// those fields exist on the model.
class _AttributeRow extends StatelessWidget {
  const _AttributeRow({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.bed_outlined, color: AppColors.grey500, size: 15),
            const SizedBox(width: 4),
            Text(
              '${property.bedrooms} bedroom${property.bedrooms == 1 ? '' : 's'}',
              style: AppTextStyles.meta,
            ),
          ],
        ),
        if (property.reviewCount > 0)
          Row(
            children: [
              const Icon(Icons.star, color: AppColors.grey300, size: 14),
              const SizedBox(width: 4),
              Text(
                '${property.averageRating.toStringAsFixed(1)} (${property.reviewCount})',
                style: AppTextStyles.meta,
              ),
            ],
          ),
      ],
    );
  }
}
