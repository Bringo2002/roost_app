import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class FullScreenImageGallery extends StatefulWidget {
  const FullScreenImageGallery({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.initialCoverMode = false,
  });

  final List<String> imageUrls;
  final int initialIndex;
  final bool initialCoverMode;

  static void open(
    BuildContext context,
    List<String> imageUrls, {
    int initialIndex = 0,
    bool initialCoverMode = false,
  }) {
    if (imageUrls.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImageGallery(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
          initialCoverMode: initialCoverMode,
        ),
      ),
    );
  }

  @override
  State<FullScreenImageGallery> createState() => _FullScreenImageGalleryState();
}

class _FullScreenImageGalleryState extends State<FullScreenImageGallery> with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final TransformationController _transformationController;
  late int _currentIndex;
  late bool _isCoverMode;

  // --- Drag-to-dismiss (Stage 1: gesture + visual feel only) ---
  //
  // This stage deliberately always springs back to rest on release --
  // it does not yet dismiss the viewer. That keeps the gesture-arena
  // behavior (vs. InteractiveViewer's pan/zoom and PageView's swipe)
  // reviewable and on-device-testable in isolation, before adding an
  // actual threshold-triggered pop and deciding what the background
  // should do while that's in flight (a separate, bigger follow-up).
  //
  // Drag distance, in logical pixels, at which the visual effect
  // reaches its full (clamped) strength.
  static const double _dismissMaxDrag = 280;
  late final AnimationController _snapBackController;
  Animation<double>? _snapBackAnimation;
  double _dismissDy = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _isCoverMode = widget.initialCoverMode;
    _pageController = PageController(initialPage: _currentIndex);
    _transformationController = TransformationController();
    _snapBackController = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.dispose();
    _snapBackController.dispose();
    super.dispose();
  }

  bool get _isZoomedOrPanned => _transformationController.value != Matrix4.identity();

  void _handleDismissDragStart(DragStartDetails details) {
    if (_isZoomedOrPanned) return;
    _snapBackController.stop();
  }

  void _handleDismissDragUpdate(DragUpdateDetails details) {
    if (_isZoomedOrPanned) return;
    // Downward-dismiss only: once back at rest, ignore further upward
    // movement rather than letting it go negative -- InteractiveViewer
    // (once it re-claims the gesture, e.g. after a zoom) owns that.
    if (_dismissDy == 0 && details.delta.dy < 0) return;
    setState(() => _dismissDy = (_dismissDy + details.delta.dy).clamp(0.0, double.infinity));
  }

  void _handleDismissDragEnd(DragEndDetails details) {
    if (_dismissDy == 0) return;
    final curved = CurvedAnimation(parent: _snapBackController, curve: Curves.easeOutCubic);
    _snapBackAnimation = Tween<double>(begin: _dismissDy, end: 0).animate(curved)
      ..addListener(() => setState(() => _dismissDy = _snapBackAnimation!.value));
    _snapBackController.forward(from: 0);
  }

  void _toggleFitMode() {
    setState(() {
      _isCoverMode = !_isCoverMode;
      _transformationController.value = Matrix4.identity();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dismissProgress = (_dismissDy / _dismissMaxDrag).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            onVerticalDragStart: _handleDismissDragStart,
            onVerticalDragUpdate: _handleDismissDragUpdate,
            onVerticalDragEnd: _handleDismissDragEnd,
            child: Transform.translate(
              offset: Offset(0, _dismissDy),
              child: Transform.scale(
                scale: 1 - (dismissProgress * 0.12),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.imageUrls.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                      _transformationController.value = Matrix4.identity();
                    });
                  },
                  itemBuilder: (context, index) {
                    final url = widget.imageUrls[index];
                    return GestureDetector(
                      onDoubleTap: _toggleFitMode,
                      child: InteractiveViewer(
                        transformationController: _transformationController,
                        minScale: 0.8,
                        maxScale: 5.0,
                        child: SizedBox.expand(
                          child: CachedNetworkImage(
                            imageUrl: url,
                            width: double.infinity,
                            height: double.infinity,
                            fit: _isCoverMode ? BoxFit.cover : BoxFit.contain,
                            filterQuality: FilterQuality.high,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white70,
                                strokeWidth: 2,
                              ),
                            ),
                            errorWidget: (context, url, error) => const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image_outlined, color: Colors.grey, size: 48),
                                SizedBox(height: 8),
                                Text(
                                  'Could not load image',
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ), // PageView.builder
              ), // Transform.scale
            ), // Transform.translate
          ), // GestureDetector (drag-to-dismiss)

          // Top Header Bar with Close Button, Fit/Fill Toggle, and Counter
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 26),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Row(
                    children: [
                      if (widget.imageUrls.length > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24, width: 0.5),
                          ),
                          child: Text(
                            '${_currentIndex + 1} / ${widget.imageUrls.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      IconButton(
                        icon: Icon(
                          _isCoverMode ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                        tooltip: _isCoverMode ? 'Fit to screen' : 'Fill screen',
                        onPressed: _toggleFitMode,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
