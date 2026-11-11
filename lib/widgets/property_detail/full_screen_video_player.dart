import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:roost_app/l10n/generated/app_localizations.dart';
import 'package:roost_app/theme/app_colors.dart';

/// Full-screen video player that opens when the user taps the property video
/// in the hero media gallery. Provides play/pause, mute/unmute, a scrub bar,
/// and a close button.
class FullScreenVideoPlayer extends StatefulWidget {
  const FullScreenVideoPlayer({super.key, required this.videoUrl});

  final String videoUrl;

  /// Pushes a full-screen video player route for [videoUrl].
  static void open(BuildContext context, String videoUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenVideoPlayer(videoUrl: videoUrl),
      ),
    );
  }

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _failed = false;
  bool _muted = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      )..setLooping(true);
      _controller = controller;

      await controller.initialize();
      if (!mounted) return;
      setState(() => _initialized = true);
      controller.play();

      // Listen for play-state changes to keep UI in sync.
      controller.addListener(_onVideoUpdate);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _onVideoUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    final c = _controller;
    if (c == null) return;
    HapticFeedback.lightImpact();
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
  }

  void _toggleMute() {
    HapticFeedback.lightImpact();
    setState(() {
      _muted = !_muted;
      _controller?.setVolume(_muted ? 0 : 1);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Video content
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            child: Center(child: _buildVideoContent()),
          ),

          // Controls overlay
          if (_showControls && _initialized && !_failed) ...[
            // Top bar: close button
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopBar(l10n),
            ),

            // Center play/pause
            Center(
              child: _buildPlayPauseButton(),
            ),

            // Bottom bar: progress + mute
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomBar(l10n),
            ),
          ],

          // Close button always visible on error/loading
          if (!_initialized || _failed)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopBar(l10n),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoContent() {
    if (_failed) {
      return const Icon(
        Icons.videocam_off_outlined,
        color: AppColors.grey500,
        size: 64,
      );
    }

    final controller = _controller;
    if (controller == null || !_initialized) {
      return const SizedBox(
        width: 36,
        height: 36,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.grey400,
        ),
      );
    }

    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: controller.value.size.width,
        height: controller.value.size.height,
        child: VideoPlayer(controller),
      ),
    );
  }

  Widget _buildTopBar(AppLocalizations l10n) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.white, size: 26),
              tooltip: l10n.photoViewerClose,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayPauseButton() {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();

    final isPlaying = controller.value.isPlaying;

    return GestureDetector(
      onTap: _togglePlayPause,
      child: AnimatedOpacity(
        opacity: _showControls ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: AppColors.white,
            size: 40,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(AppLocalizations l10n) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            if (_controller != null)
              VideoProgressIndicator(
                _controller!,
                allowScrubbing: true,
                colors: VideoProgressColors(
                  playedColor: AppColors.white,
                  bufferedColor: AppColors.white.withValues(alpha: 0.3),
                  backgroundColor: AppColors.white.withValues(alpha: 0.1),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),

            // Mute button row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(
                    _muted ? Icons.volume_off : Icons.volume_up,
                    color: AppColors.white,
                    size: 24,
                  ),
                  tooltip: _muted
                      ? l10n.heroGalleryUnmuteVideo
                      : l10n.heroGalleryMuteVideo,
                  onPressed: _toggleMute,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
