import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/widgets/common/full_screen_image_gallery.dart';
import 'package:roost_app/widgets/property_detail/glass_icon_button.dart';

const double kHeroMediaHeight = 340;

class HeroMediaGallery extends StatefulWidget {
  const HeroMediaGallery({super.key, required this.property});

  final Property property;

  @override
  State<HeroMediaGallery> createState() => _HeroMediaGalleryState();
}

class _HeroMediaGalleryState extends State<HeroMediaGallery> {
  int _currentIndex = 0;

  List<String> get _photoUrls {
    final urls = <String>[];
    if (widget.property.imageUrl != null && widget.property.imageUrl!.isNotEmpty) {
      urls.add(widget.property.imageUrl!);
    }
    for (final url in widget.property.imageUrls) {
      if (url.isNotEmpty && !urls.contains(url)) {
        urls.add(url);
      }
    }
    return urls;
  }

  bool get _hasVideo => widget.property.videoUrl != null && widget.property.videoUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final urls = _photoUrls;
    final slideCount = urls.length + (_hasVideo ? 1 : 0);

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildGallery(urls, slideCount),
        _buildBottomScrim(),
        if (slideCount > 1) _buildDotIndicator(slideCount),
        if (slideCount > 1) _buildPhotoCounter(slideCount),
      ],
    );
  }

  Widget _buildGallery(List<String> urls, int slideCount) {
    if (slideCount == 0) {
      return Container(
        color: AppColors.surface,
        child: const Center(
          child: Icon(Icons.home_outlined, color: AppColors.grey700, size: 64),
        ),
      );
    }

    return PageView.builder(
      itemCount: slideCount,
      onPageChanged: (idx) => setState(() => _currentIndex = idx),
      itemBuilder: (context, idx) {
        if (_hasVideo && idx == 0) {
          return _HeroVideoSlide(url: widget.property.videoUrl!);
        }
        final photoIdx = _hasVideo ? idx - 1 : idx;
        return GestureDetector(
          onTap: () => FullScreenImageGallery.open(context, urls, initialIndex: photoIdx),
          child: CachedNetworkImage(
            imageUrl: urls[photoIdx],
            fit: BoxFit.cover,
            placeholder: (context, url) => Shimmer.fromColors(
              baseColor: AppColors.grey800,
              highlightColor: AppColors.grey700,
              child: Container(color: AppColors.black),
            ),
            errorWidget: (context, url, error) => Container(
              color: AppColors.surface,
              child: const Icon(Icons.broken_image, color: AppColors.grey500, size: 48),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomScrim() {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
            stops: const [0.0, 0.5],
          ),
        ),
      ),
    );
  }

  Widget _buildDotIndicator(int slideCount) {
    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(slideCount, (i) {
          final active = i == _currentIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            width: active ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: active ? AppColors.white : AppColors.scrimLight,
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPhotoCounter(int slideCount) {
    return Positioned(
      bottom: 16,
      right: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Text(
              '${_currentIndex + 1} / $slideCount',
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroVideoSlide extends StatefulWidget {
  const _HeroVideoSlide({required this.url});

  final String url;

  @override
  State<_HeroVideoSlide> createState() => _HeroVideoSlideState();
}

class _HeroVideoSlideState extends State<_HeroVideoSlide> {
  VideoPlayerController? _controller;
  bool _muted = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller?.play();
      }).catchError((_) {
        if (mounted) setState(() => _failed = true);
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _toggleMute() {
    setState(() {
      _muted = !_muted;
      _controller?.setVolume(_muted ? 0 : 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Container(
        color: AppColors.surface,
        child: const Center(
          child: Icon(Icons.videocam_off_outlined, color: AppColors.grey500, size: 40),
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return Container(
        color: AppColors.black,
        child: const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.grey400),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _toggleMute,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            child: GlassIconButton(
              icon: _muted ? Icons.volume_off : Icons.volume_up,
              onTap: _toggleMute,
            ),
          ),
        ],
      ),
    );
  }
}
