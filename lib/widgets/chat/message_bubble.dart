import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:roost_app/models/message.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/theme/app_text_styles.dart';
import 'package:roost_app/theme/app_theme.dart';

/// A single chat message bubble -- text, an attachment (image or file), or
/// both. Consecutive messages from the same sender are visually grouped:
/// only the last one in a group shows a timestamp/read-receipt and a fully
/// rounded tail corner, keeping dense conversations readable.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.isGroupEnd = true,
  });

  final Message message;
  final bool isMe;

  /// Whether this is the last message in a run of consecutive messages
  /// from the same sender (controls timestamp/receipt visibility and tail
  /// radius).
  final bool isGroupEnd;

  @override
  Widget build(BuildContext context) {
    final tailRadius = isGroupEnd ? const Radius.circular(4) : const Radius.circular(20);
    final hasText = message.content.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: isGroupEnd ? 12 : 3),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              child: Container(
                padding: message.hasAttachment && !hasText
                    ? const EdgeInsets.all(6)
                    : const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  color: isMe ? AppColors.white : AppColors.surfaceRaised,
                  border: isMe ? null : Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: isMe ? const Radius.circular(20) : tailRadius,
                    bottomRight: isMe ? tailRadius : const Radius.circular(20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.hasAttachment) _Attachment(message: message, isMe: isMe),
                    if (message.hasAttachment && hasText) const SizedBox(height: 8),
                    if (hasText)
                      Text(
                        message.content,
                        style: AppTextStyles.body.copyWith(
                          color: isMe ? AppColors.black : AppColors.textPrimary,
                        ),
                      ),
                    if (message.hasAttachment && hasText) const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
            if (isGroupEnd) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('h:mm a').format(message.timestamp.toLocal()),
                      style: AppTextStyles.meta.copyWith(fontSize: 11),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 3),
                      Icon(
                        message.read ? Icons.done_all : Icons.done,
                        size: 14,
                        color: message.read ? AppColors.white : AppColors.grey500,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Attachment extends StatelessWidget {
  const _Attachment({required this.message, required this.isMe});

  final Message message;
  final bool isMe;

  bool get _isImage => (message.attachmentMimeType ?? '').startsWith('image/');

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
