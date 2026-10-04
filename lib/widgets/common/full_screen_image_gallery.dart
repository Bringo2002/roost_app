import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:roost_app/l10n/generated/app_localizations.dart';

/// Drag distance, in logical pixels, past which letting go dismisses the viewer.
const double photoViewerDismissDistance = 120;

/// Fling speed, in logical pixels per second, that decides the outcome
/// regardless of distance. Same value Flutter's own [Dismissible] uses.
const double photoViewerDismissFlingVelocity = 700;

/// Drag distance, in logical pixels, at which the drag's visual effects
/// reach their full (clamped) strength.
const double photoViewerDragEffectDistance = 280;

/// Whether releasing a downward drag should dismiss the viewer (true) or
/// snap the photo back (false).
///
/// A decisive fling wins over distance in either direction: a hard downward
/// flick dismisses after a short drag, and a hard upward flick cancels even a
/// long drag (the user reversed course). Otherwise distance decides.
@visibleForTesting
bool shouldDismissPhotoViewer({required double dragDistance, required double velocityY}) {
  if (velocityY >= photoViewerDismissFlingVelocity) return true;
  if (velocityY <= -photoViewerDismissFlingVelocity) return false;
  return dragDistance >= photoViewerDismissDistance;
}

/// Opacity of the viewer's header (close button, counter, fit toggle) for a
/// downward drag of [dragDistance]: fully opaque at rest, fully faded once the
/// drag reaches [photoViewerDragEffectDistance].
///
/// Clamped, so the result stays valid for [Opacity] however far the photo is
/// dragged or flung.
@visibleForTesting
double photoViewerChromeOpacity(double dragDistance) =>
    1 - (dragDistance / photoViewerDragEffectDistance).clamp(0.0, 1.0);

class FullScreenImageGallery extends StatefulWidget {
  const FullScreenImageGallery({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.initialCoverMode = false,
    this.heroTagFor,
  });

  final List<String> imageUrls;
  final int initialIndex;
  final bool initialCoverMode;

  /// [Hero] tag for the photo at an index. When set, each photo shares a Hero
  /// with the caller's matching thumbnail, so the photo flies between the two
  /// on open and close. Leave null for no Hero (e.g. avatars).
  final Object Function(int index)? heroTagFor;

  static void open(
    BuildContext context,
    List<String> imageUrls, {
    int initialIndex = 0,
    bool initialCoverMode = false,
    Object Function(int index)? heroTagFor,
  }) {
    if (imageUrls.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImageGallery(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
          initialCoverMode: initialCoverMode,
          heroTagFor: heroTagFor,
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

  // --- Drag-to-dismiss ---
  //
  // A downward drag translates and slightly shrinks the photo. On release
  // it either springs back or, per [shouldDismissPhotoViewer], carries the
  // photo off-screen and pops the route.
  //
  // The background stays solid black. Revealing the previous page behind
  // the photo would need a non-opaque route, which keeps that page mounted
  // underneath -- a bigger decision than this gesture.
  //
  // Fraction of scale lost at full drag strength (0.12 -> 88%).
  static const double _dragScaleLoss = 0.12;
  // Scale the photo shrinks to by the time it has left the screen.
  static const double _exitEndScale = 0.5;
  late final AnimationController _dragReleaseController;
  Animation<double>? _dragReleaseAnimation;
  double _dismissDy = 0;
  bool _isDismissing = false;
  // Where the exit started and where it ends, so the exit's scale/fade can
  // begin exactly from what the drag was showing (no jump on release).
  double _dismissStartDy = 0;
  double _dismissTargetDy = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _isCoverMode = widget.initialCoverMode;
    _pageController = PageController(initialPage: _currentIndex);
    _transformationController = TransformationController();
    _dragReleaseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 220))
      ..addListener(_handleDragReleaseTick);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.dispose();
    _dragReleaseController.dispose();
    super.dispose();
  }

  // Scale for a drag of [dy]: eases from 1 down to (1 - _dragScaleLoss).
  double _dragScale(double dy) => 1 - (dy / photoViewerDragEffectDistance).clamp(0.0, 1.0) * _dragScaleLoss;

  bool get _isZoomedOrPanned => _transformationController.value != Matrix4.identity();

  // The OS "reduce motion" / "remove animations" setting. The drag following
  // the finger is direct manipulation and stays; the animations that play on
  // their own (snap-back, exit, Hero flights) are skipped.
  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  void _handleDismissDragStart(DragStartDetails details) {
    if (_isDismissing || _isZoomedOrPanned) return;
    _dragReleaseController.stop();
  }

  void _handleDismissDragUpdate(DragUpdateDetails details) {
    if (_isDismissing || _isZoomedOrPanned) return;
    // Downward-dismiss only: once back at rest, ignore further upward
    // movement rather than letting it go negative -- InteractiveViewer
    // (once it re-claims the gesture, e.g. after a zoom) owns that.
    if (_dismissDy == 0 && details.delta.dy < 0) return;
    setState(() => _dismissDy = (_dismissDy + details.delta.dy).clamp(0.0, double.infinity));
  }

  void _handleDismissDragEnd(DragEndDetails details) {
    if (_isDismissing || _dismissDy == 0) return;
    final shouldDismiss = shouldDismissPhotoViewer(
      dragDistance: _dismissDy,
      velocityY: details.velocity.pixelsPerSecond.dy,
    );
    if (shouldDismiss) {
      _startDismiss();
    } else if (_reduceMotion) {
      setState(() => _dismissDy = 0);
    } else {
      _animateDragRelease(to: 0, curve: Curves.easeOutCubic);
    }
  }

  void _startDismiss() {
    if (_reduceMotion) {
      _popIfCurrent();
      return;
    }
    final screenHeight = MediaQuery.sizeOf(context).height;
    // Already dragged fully off-screen: nothing left to animate.
    if (_dismissDy >= screenHeight) {
      _popIfCurrent();
      return;
    }
    setState(() {
      _isDismissing = true;
      _dismissStartDy = _dismissDy;
      _dismissTargetDy = screenHeight;
    });
    // Carry the photo off-screen ourselves and only pop afterwards. Popping
    // now would start the route's own exit transition from wherever the
    // finger let go, compounding with this manual transform (a visible
    // jump). By the time the route animates out, the photo is already gone.
    _animateDragRelease(to: screenHeight, curve: Curves.easeIn).whenComplete(_popIfCurrent);
  }

  // The close button or system back may have popped the route while the exit
  // animation was still running (the route stays mounted through its own exit
  // transition), so only pop if this route is still the current one -- a second
  // pop would take down the page underneath.
  void _popIfCurrent() {
    if (!mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    Navigator.pop(context);
  }

  void _handleDragReleaseTick() {
    final animation = _dragReleaseAnimation;
    if (animation == null) return;
    setState(() => _dismissDy = animation.value);
  }

  // Animates [_dismissDy] from wherever the drag was released to [to]. The
  // animation is rebuilt per release (its begin value differs each time) but
  // the tick listener lives on the controller and is registered once:
  // listeners added to a derived animation land on the controller and are
  // never removed, so one per release would pile up and each call setState.
  TickerFuture _animateDragRelease({required double to, required Curve curve}) {
    _dragReleaseAnimation = _dragReleaseController.drive(
      Tween<double>(begin: _dismissDy, end: to).chain(CurveTween(curve: curve)),
    );
    return _dragReleaseController.forward(from: 0);
  }

  void _toggleFitMode() {
    setState(() {
      _isCoverMode = !_isCoverMode;
      _transformationController.value = Matrix4.identity();
    });
  }

  Widget _buildPhoto(String url) {
    return SizedBox.expand(
      child: CachedNetworkImage(
        imageUrl: url,
        width: double.infinity,
        height: double.infinity,
        fit: _isCoverMode ? BoxFit.cover : BoxFit.contain,
        filterQuality: FilterQuality.high,
        placeholder: (context, url) => Center(
          child: CircularProgressIndicator(
            color: Colors.white70,
            strokeWidth: 2,
            semanticsLabel: AppLocalizations.of(context)!.photoViewerLoading,
          ),
        ),
        errorWidget: (context, url, error) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 48),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.photoViewerLoadFailed,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // Wraps [photo] in a Hero shared with the caller's thumbnail, when the caller
  // supplied tags.
  Widget _withHero(int index, Widget photo) {
    final tagFor = widget.heroTagFor;
    if (tagFor == null) return photo;
    return HeroMode(
      // Off for the drag-dismiss exit: the photo has already left the screen
      // and faded by the time the route pops, so a Hero flight would start
      // from that off-screen rect and fly it back into view. Also off when the
      // user asked for reduced motion.
      enabled: !_isDismissing && !_reduceMotion,
      child: Hero(
        tag: tagFor(index),
        curve: Curves.easeOutCubic,
        // Needed on both ends for the flight to run on a swipe-back too.
        transitionOnUserGestures: true,
        flightShuttleBuilder: _buildHeroFlightShuttle,
        child: photo,
      ),
    );
  }

  // Always fly the viewer's own (fit: contain) photo. The default shuttle shows
  // the destination's child, which on close is the thumbnail's cropped image
  // starting at full-screen size -- a jarring reframe on the first frame.
  // Flutter prefers the destination Hero's builder and falls back to the
  // source's, so setting it on the viewer's Hero alone covers both directions.
  Widget _buildHeroFlightShuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromContext,
    BuildContext toContext,
  ) {
    final viewerContext = direction == HeroFlightDirection.push ? toContext : fromContext;
    return (viewerContext.widget as Hero).child;
  }

  Widget _buildPhotoPager() {
    return PageView.builder(
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
            child: Semantics(
              image: true,
              label: AppLocalizations.of(context)!.photoPositionLabel(index + 1, widget.imageUrls.length),
              child: _withHero(index, _buildPhoto(url)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 26),
              tooltip: l10n.photoViewerClose,
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
                    child: Semantics(
                      label: l10n.mediaPositionLabel(_currentIndex + 1, widget.imageUrls.length),
                      liveRegion: true,
                      excludeSemantics: true,
                      child: Text(
                        '${_currentIndex + 1} / ${widget.imageUrls.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                IconButton(
                  icon: Icon(
                    _isCoverMode ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                  tooltip: _isCoverMode ? l10n.photoViewerFitToScreen : l10n.photoViewerFillScreen,
                  onPressed: _toggleFitMode,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var scale = _dragScale(_dismissDy);
    var opacity = 1.0;
    if (_isDismissing) {
      // Progress along the exit run only (0 at release, 1 once off-screen), so
      // the shrink and fade pick up from what the drag showed at release.
      final exitProgress =
          ((_dismissDy - _dismissStartDy) / (_dismissTargetDy - _dismissStartDy)).clamp(0.0, 1.0);
      final startScale = _dragScale(_dismissStartDy);
      scale = startScale + (_exitEndScale - startScale) * exitProgress;
      opacity = 1 - exitProgress;
    }

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
                scale: scale,
                child: Opacity(opacity: opacity, child: _buildPhotoPager()),
              ), // Transform.scale
            ), // Transform.translate
          ), // GestureDetector (drag-to-dismiss)

          // Top Header Bar with Close Button, Fit/Fill Toggle, and Counter.
          // Fades with the drag so it doesn't sit stuck in place while the
          // photo moves away.
          Opacity(opacity: photoViewerChromeOpacity(_dismissDy), child: _buildHeader()),
        ],
      ),
    );
  }
}
