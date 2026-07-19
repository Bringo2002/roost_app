import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:roost_app/theme/app_colors.dart';

class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({
    super.key,
    required this.videoBytes,
    required this.fileName,
  });

  final Uint8List videoBytes;
  final String fileName;

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  String? _error;
  File? _tempFile;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final dir = await getTemporaryDirectory();
      _tempFile = File('${dir.path}/${widget.fileName}');
      await _tempFile!.writeAsBytes(widget.videoBytes);

      _controller = VideoPlayerController.file(_tempFile!);
      await _controller!.initialize();
      setState(() {
        _initialized = true;
      });
      _controller!.play();
    } catch (e) {
      setState(() {
        _error = 'Failed to load video: $e';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    try {
      _tempFile?.delete();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.fileName, style: const TextStyle(color: AppColors.white)),
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      body: Center(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Text(_error!, style: const TextStyle(color: Colors.redAccent));
    }
    if (!_initialized) {
      return const CircularProgressIndicator(color: AppColors.white);
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          VideoPlayer(_controller!),
          _ControlsOverlay(controller: _controller!),
          VideoProgressIndicator(_controller!, allowScrubbing: true),
        ],
      ),
    );
  }
}

class _ControlsOverlay extends StatefulWidget {
  const _ControlsOverlay({required this.controller});

  final VideoPlayerController controller;

  @override
  State<_ControlsOverlay> createState() => _ControlsOverlayState();
}

class _ControlsOverlayState extends State<_ControlsOverlay> {
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 50),
      child: widget.controller.value.isPlaying
          ? GestureDetector(
              onTap: () {
                widget.controller.pause();
                setState(() {});
              },
              child: Container(
                color: Colors.transparent,
              ),
            )
          : Container(
              color: Colors.black45,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.play_arrow, color: Colors.white, size: 50.0),
                  onPressed: () {
                    widget.controller.play();
                    setState(() {});
                  },
                ),
              ),
            ),
    );
  }
}
