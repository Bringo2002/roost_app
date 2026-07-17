import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class PropertyImage extends StatelessWidget {
  const PropertyImage({
    super.key,
    required this.imageUrl,
    this.height = 180,
    this.width = double.infinity,
    this.borderRadius = BorderRadius.zero,
    this.overlay,
  });

  final String? imageUrl;
  final double height;
  final double width;
  final BorderRadius borderRadius;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        children: [
          SizedBox(
            height: height,
            width: width,
            child: hasImage
                ? CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: Colors.grey[850],
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => _fallback(),
                  )
                : _fallback(),
          ),
          if (overlay != null) Positioned.fill(child: overlay!),
        ],
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: Colors.grey[850],
      alignment: Alignment.center,
      child: Icon(Icons.home_outlined, color: Colors.grey[600], size: 34),
    );
  }
}
