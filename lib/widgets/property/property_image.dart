import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:roost_app/theme/app_colors.dart';

/// Displays a property's image (or swipeable gallery, when more than one
/// URL is provided) with a fade-in placeholder, a graceful error fallback,
/// an optional Hero transition, and optional overlay slots for a favorite
/// button / status badge supplied by the caller.
class PropertyImage extends StatefulWidget {
  const PropertyImage({
    super.key,
    required this.imageUrls,
    this.height = 220,
    this.width = double.infinity,
    this.borderRadius = BorderRadius.zero,
    this.heroTag,
    this.topLeft,
    this.topRight,
  });

  /// All image URLs for this listing, already de-duplicated by the caller.
  /// An empty list renders the fallback state.
  final List<String> imageUrls;
  final double height;
  final double width;
  final BorderRadius borderRadius;

  /// When set, wraps the image in a [Hero] for a shared-element transition
  /// into the property detail page.
  final Object? heroTag;

  final Widget? topLeft;
  final Widget? topRight;

  @override
  State<PropertyImage> createState() => _PropertyImageState();
}

class _PropertyImageState extends State<PropertyImage> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content = ClipRRect(
      borderRadius: widget.borderRadius,
      child: SizedBox(
        height: widget.height,
        width: widget.width,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildGallery(),
            if (widget.imageUrls.length > 1) _buildPageIndicator(),
            if (widget.topLeft != null)
              Positioned(left: 10, top: 10, child: widget.topLeft!),
            if (widget.topRight != null)
              Positioned(right: 10, top: 10, child: widget.topRight!),
          ],
        ),
      ),
    );

    if (widget.heroTag != null) {
      content = Hero(tag: widget.heroTag!, child: content);
    }

    return content;
  }

  Widget _buildGallery() {
    if (widget.imageUrls.isEmpty) return _fallback();

    if (widget.imageUrls.length == 1) {
      return _networkImage(widget.imageUrls.first);
    }

    return PageView.builder(
      controller: _controller,
      itemCount: widget.imageUrls.length,
      onPageChanged: (i) => setState(() => _index = i),
      itemBuilder: (_, i) => _networkImage(widget.imageUrls[i]),
    );
  }

  Widget _networkImage(String url) {
    if (url.trim().isEmpty) return _fallback();

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => Container(
        color: AppColors.surface,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.grey400,
          ),
        ),
      ),
      errorWidget: (_, __, ___) => _fallback(),
    );
  }

  Widget _fallback() {
    return Container(
      color: AppColors.surface,
      alignment: Alignment.center,
      child: const Icon(
        Icons.home_outlined,
        color: AppColors.grey600,
        size: 34,
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Positioned(
      bottom: 10,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.imageUrls.length, (i) {
          final active = i == _index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: active ? 14 : 5,
            height: 5,
            decoration: BoxDecoration(
              color: active ? AppColors.white : AppColors.scrimLight,
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      ),
    );
  }
}
