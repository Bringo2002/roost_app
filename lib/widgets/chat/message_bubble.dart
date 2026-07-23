import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:roost_app/models/message.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/theme/app_text_styles.dart';
import 'package:roost_app/pages/chat/video_player_page.dart';
import 'package:roost_app/services/link_preview_service.dart';

class MessageBubble extends StatefulWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.isGroupEnd = true,
    this.replyMessage,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.onReact,
    required this.onForward,
  });

  final Message message;
  final bool isMe;
  final bool isGroupEnd;
  final Message? replyMessage;
  final VoidCallback onReply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(String) onReact;
  final VoidCallback onForward;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animController.addListener(() {
      setState(() {
        _dragOffset = _animController.value * _dragOffset;
      });
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx).clamp(-80.0, 0.0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_dragOffset <= -50.0) {
      widget.onReply();
    }
    _animController.value = 1.0;
    _animController.reverse();
  }

  int get _currentUserId => widget.isMe ? widget.message.sender.id : widget.message.recipient.id;

  bool _hasReacted(String emoji) {
    return widget.message.reactions.any((r) => r.emoji == emoji && r.user.id == _currentUserId);
  }

  Map<String, int> _groupReactions() {
    final Map<String, int> counts = {};
    for (final r in widget.message.reactions) {
      counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
    }
    return counts;
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['👍', '❤️', '🔥', '😂', '😮', '😢'].map((emoji) {
                    final active = _hasReacted(emoji);
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        widget.onReact(emoji);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: active ? AppColors.white.withValues(alpha: 0.15) : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              ListTile(
                leading: const Icon(Icons.reply_outlined, color: AppColors.white),
                title: const Text('Reply', style: TextStyle(color: AppColors.white)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onReply();
                },
              ),
              ListTile(
                leading: const Icon(Icons.forward_outlined, color: AppColors.white),
                title: const Text('Forward', style: TextStyle(color: AppColors.white)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onForward();
                },
              ),
              if (widget.message.content.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.copy_all_outlined, color: AppColors.white),
                  title: const Text('Copy Text', style: TextStyle(color: AppColors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    Clipboard.setData(ClipboardData(text: widget.message.content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')),
                    );
                  },
                ),
              if (widget.isMe && !widget.message.hasAttachment)
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: AppColors.white),
                  title: const Text('Edit Message', style: TextStyle(color: AppColors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onEdit();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onDelete();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tailRadius = widget.isGroupEnd ? const Radius.circular(4) : const Radius.circular(20);
    final hasText = widget.message.content.isNotEmpty;
    final grouped = _groupReactions();
    final firstUrl = hasText ? LinkPreviewService.extractUrl(widget.message.content) : null;

    return Padding(
      padding: EdgeInsets.only(bottom: widget.isGroupEnd ? 12 : 3),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (_dragOffset < 0)
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: Opacity(
                  opacity: (_dragOffset / -80.0).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: (_dragOffset / -80.0).clamp(0.4, 1.0),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.reply,
                        color: AppColors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          GestureDetector(
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            onLongPress: () => _showContextMenu(context),
            child: Transform.translate(
              offset: Offset(_dragOffset, 0),
              child: Align(
                alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      child: Container(
                        padding: widget.message.hasAttachment && !hasText
                            ? const EdgeInsets.all(6)
                            : const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        decoration: BoxDecoration(
                          color: widget.isMe ? AppColors.white : AppColors.surfaceRaised,
                          border: widget.isMe ? null : Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: widget.isMe ? const Radius.circular(20) : tailRadius,
                            bottomRight: widget.isMe ? tailRadius : const Radius.circular(20),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.replyMessage != null)
                              _ReplyPreviewBlock(replyMessage: widget.replyMessage!, isMe: widget.isMe),
                            if (widget.message.hasAttachment)
                              _Attachment(message: widget.message, isMe: widget.isMe),
                            if (widget.message.hasAttachment && hasText) const SizedBox(height: 8),
                            if (hasText)
                              Text(
                                widget.message.content,
                                style: widget.message.content == '🔒 Sent from another device'
                                    ? TextStyle(color: Colors.grey[500], fontSize: 13)
                                    : AppTextStyles.body.copyWith(
                                        color: widget.isMe ? AppColors.black : AppColors.textPrimary,
                                      ),
                              ),
                            if (firstUrl != null)
                              _LinkPreviewWidget(url: firstUrl, isMe: widget.isMe),
                            if (widget.message.hasAttachment && hasText) const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    ),
                    if (grouped.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 2),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: grouped.entries.map((entry) {
                            final emoji = entry.key;
                            final count = entry.value;
                            final active = _hasReacted(emoji);

                            return GestureDetector(
                              onTap: () => widget.onReact(emoji),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: active
                                      ? AppColors.white.withValues(alpha: 0.15)
                                      : AppColors.surfaceRaised,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: active ? AppColors.white : AppColors.divider,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(emoji, style: const TextStyle(fontSize: 12)),
                                    if (count > 1) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        '$count',
                                        style: TextStyle(
                                          color: active ? AppColors.white : AppColors.textSecondary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    if (widget.isGroupEnd) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat('h:mm a').format(widget.message.timestamp.toLocal()) +
                                  (widget.message.edited ? ' (edited)' : ''),
                              style: AppTextStyles.meta.copyWith(fontSize: 11),
                            ),
                            if (widget.isMe) ...[
                              const SizedBox(width: 3),
                              Icon(
                                widget.message.read ? Icons.done_all : Icons.done,
                                size: 14,
                                color: widget.message.read ? AppColors.white : AppColors.grey500,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyPreviewBlock extends StatelessWidget {
  const _ReplyPreviewBlock({required this.replyMessage, required this.isMe});

  final Message replyMessage;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final senderName = replyMessage.sender.name;
    final text = replyMessage.content.isNotEmpty
        ? replyMessage.content
        : (replyMessage.hasAttachment ? '📎 Attachment' : '');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isMe
                ? AppColors.black.withValues(alpha: 0.4)
                : AppColors.white.withValues(alpha: 0.4),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            senderName,
            style: TextStyle(
              color: isMe ? AppColors.black : AppColors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: (isMe ? AppColors.black : AppColors.textSecondary).withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _Attachment extends StatelessWidget {
  const _Attachment({required this.message, required this.isMe});

  final Message message;
  final bool isMe;

  bool get _isImage => (message.attachmentMimeType ?? '').startsWith('image/');
  bool get _isVideo => (message.attachmentMimeType ?? '').startsWith('video/');
  bool get _isAudio => (message.attachmentMimeType ?? '').startsWith('audio/');

  @override
  Widget build(BuildContext context) {
    final bytes = message.attachmentBytes;

    if (bytes == null) {
      return _AttachmentPlaceholder(
        isMe: isMe,
        icon: Icons.error_outline,
        label: "Couldn't load attachment",
      );
    }

    if (_isImage) {
      return GestureDetector(
        onTap: () => _openImageViewer(context, bytes),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.memory(
            bytes,
            width: 220,
            height: 220,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _AttachmentPlaceholder(
              isMe: isMe,
              icon: Icons.broken_image_outlined,
              label: 'Image unavailable',
            ),
          ),
        ),
      );
    }

    if (_isVideo) {
      return _VideoAttachmentPreview(message: message, isMe: isMe);
    }

    if (_isAudio) {
      return _VoiceMessagePlayer(message: message, isMe: isMe);
    }

    return _FileChip(
      fileName: message.attachmentFileName ?? 'File',
      sizeBytes: message.attachmentSizeBytes,
      bytes: bytes,
      isMe: isMe,
    );
  }

  void _openImageViewer(BuildContext context, Uint8List bytes) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: AppColors.black,
        pageBuilder: (context, _, _) => _ImageViewer(bytes: bytes),
      ),
    );
  }
}

class _VideoAttachmentPreview extends StatelessWidget {
  const _VideoAttachmentPreview({required this.message, required this.isMe});

  final Message message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final fg = isMe ? AppColors.black : AppColors.textPrimary;
    final size = message.attachmentSizeBytes;
    final sizeLabel = size == null
        ? ''
        : (size < 1024 * 1024
            ? '${(size / 1024).toStringAsFixed(0)} KB'
            : '${(size / (1024 * 1024)).toStringAsFixed(1)} MB');

    return GestureDetector(
      onTap: () => _openVideoPlayer(context),
      child: Container(
        width: 220,
        height: 140,
        decoration: BoxDecoration(
          color: (isMe ? AppColors.black : AppColors.white).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: (isMe ? AppColors.black : AppColors.white).withValues(alpha: 0.15),
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isMe ? AppColors.black : AppColors.white).withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow,
                  color: isMe ? AppColors.white : AppColors.black,
                  size: 28,
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  Icon(Icons.videocam_outlined, color: fg, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      message.attachmentFileName ?? 'Video',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (sizeLabel.isNotEmpty)
                    Text(
                      sizeLabel,
                      style: TextStyle(color: fg.withValues(alpha: 0.6), fontSize: 10),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openVideoPlayer(BuildContext context) {
    if (message.attachmentBytes == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoPlayerPage(
          videoBytes: message.attachmentBytes!,
          fileName: message.attachmentFileName ?? 'video.mp4',
        ),
      ),
    );
  }
}

class _VoiceMessagePlayer extends StatefulWidget {
  const _VoiceMessagePlayer({required this.message, required this.isMe});

  final Message message;
  final bool isMe;

  @override
  State<_VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<_VoiceMessagePlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _initialized = false;
  File? _tempFile;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    final bytes = widget.message.attachmentBytes;
    if (bytes == null) return;
    try {
      final dir = await getTemporaryDirectory();
      _tempFile = File('${dir.path}/voice_${widget.message.id}.m4a');
      await _tempFile!.writeAsBytes(bytes);

      await _player.setFilePath(_tempFile!.path);
      
      _posSub = _player.positionStream.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      _durSub = _player.durationStream.listen((d) {
        if (mounted && d != null) setState(() => _duration = d);
      });
      _stateSub = _player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
            if (state.processingState == ProcessingState.completed) {
              _player.seek(Duration.zero);
              _player.pause();
            }
          });
        }
      });
      if (mounted) {
        setState(() => _initialized = true);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    try {
      _tempFile?.delete();
    } catch (_) {}
    super.dispose();
  }

  void _togglePlay() {
    if (!_initialized) return;
    if (_isPlaying) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  String _formatDuration(Duration d) {
    final min = d.inMinutes;
    final sec = d.inSeconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.isMe ? AppColors.black : AppColors.white,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Loading voice note...',
            style: TextStyle(
              color: widget.isMe ? AppColors.black : AppColors.white,
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    final fg = widget.isMe ? AppColors.black : AppColors.white;
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: fg.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: fg,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    Container(
                      height: 4,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: fg.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: fg,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(color: fg.withValues(alpha: 0.6), fontSize: 10),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: TextStyle(color: fg.withValues(alpha: 0.6), fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkPreviewWidget extends StatefulWidget {
  const _LinkPreviewWidget({required this.url, required this.isMe});

  final String url;
  final bool isMe;

  @override
  State<_LinkPreviewWidget> createState() => _LinkPreviewWidgetState();
}

class _LinkPreviewWidgetState extends State<_LinkPreviewWidget> {
  LinkPreviewData? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(covariant _LinkPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _fetch();
    }
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final data = await LinkPreviewService.fetchPreview(widget.url);
    if (mounted) {
      setState(() {
        _data = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: widget.isMe ? AppColors.black : AppColors.white,
          ),
        ),
      );
    }
    if (_data == null) return const SizedBox.shrink();

    final preview = _data!;
    final fg = widget.isMe ? AppColors.black : AppColors.textPrimary;
    final bg = (widget.isMe ? AppColors.black : AppColors.white).withValues(alpha: 0.06);

    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(preview.url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: fg.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (preview.imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  preview.imageUrl!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              preview.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (preview.description != null && preview.description!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                preview.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AttachmentPlaceholder extends StatelessWidget {
  const _AttachmentPlaceholder({required this.isMe, required this.icon, required this.label});

  final bool isMe;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = isMe ? AppColors.black : AppColors.textSecondary;
    return Container(
      width: 200,
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: (isMe ? AppColors.black : AppColors.white).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(label, style: AppTextStyles.meta.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _FileChip extends StatefulWidget {
  const _FileChip({
    required this.fileName,
    required this.sizeBytes,
    required this.bytes,
    required this.isMe,
  });

  final String fileName;
  final int? sizeBytes;
  final Uint8List bytes;
  final bool isMe;

  @override
  State<_FileChip> createState() => _FileChipState();
}

class _FileChipState extends State<_FileChip> {
  bool _opening = false;

  String get _sizeLabel {
    final bytes = widget.sizeBytes;
    if (bytes == null) return '';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${widget.fileName}');
      await file.writeAsBytes(widget.bytes);
      await OpenFilex.open(file.path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't open this file")),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.isMe ? AppColors.black : AppColors.textPrimary;
    return InkWell(
      onTap: _open,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (widget.isMe ? AppColors.black : AppColors.white).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (widget.isMe ? AppColors.black : AppColors.white).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: _opening
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                    )
                  : Icon(Icons.insert_drive_file_outlined, color: fg, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(color: fg, fontSize: 13),
                  ),
                  if (_sizeLabel.isNotEmpty)
                    Text(
                      _sizeLabel,
                      style: AppTextStyles.meta.copyWith(
                        color: fg.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.memory(bytes),
        ),
      ),
    );
  }
}
