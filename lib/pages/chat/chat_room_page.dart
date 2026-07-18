import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:roost_app/models/user.dart';
import 'package:roost_app/models/message.dart';
import 'package:roost_app/services/chat_service.dart';
import 'package:roost_app/services/auth_service.dart';
import 'package:roost_app/services/encryption_service.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/theme/app_text_styles.dart';
import 'package:roost_app/theme/app_theme.dart';
import 'package:roost_app/utils/presence_formatter.dart';
import 'package:roost_app/widgets/chat/message_bubble.dart';
import 'package:intl/intl.dart';

class ChatRoomPage extends StatefulWidget {
  final User partner;

  const ChatRoomPage({super.key, required this.partner});

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Message> _messages = [];
  bool _isLoading = true;
  String? _currentUserEmail;
  Timer? _pollingTimer;
  late User _livePartner = widget.partner;

  PlatformFile? _pendingFile;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _initChat() async {
    final email = await AuthService.getUserEmail();
    if (!mounted) return;
    setState(() {
      _currentUserEmail = email;
    });

    try {
      await EncryptionService.ensureInitialized();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not set up secure messaging. Please try again.')),
      );
      return;
    }

    await _loadMessages();
    if (!mounted) return;

    // Poll for new messages and refresh partner presence every 5 seconds.
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        _loadMessages(silent: true);
        _refreshPresence();
      }
    });
  }

  Future<void> _refreshPresence() async {
    final updated = await ChatService.getUserProfile(widget.partner.id);
    if (updated != null && mounted) {
      setState(() => _livePartner = updated);
    }
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final messages = await ChatService.getChatHistory(widget.partner.id);
      if (!mounted) return;

      // Mark read in background
      ChatService.markAsRead(widget.partner.id);

      // Check if there are new messages
      bool isNewMessage = _messages.length != messages.length;

      setState(() {
        _messages = messages;
        if (!silent) _isLoading = false;
      });

      if (isNewMessage) {
        _scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load messages: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;

      if (file.bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't read that file")),
        );
        return;
      }
      if (file.bytes!.length > kMaxAttachmentBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('That file is too large (max ${kMaxAttachmentBytes ~/ (1024 * 1024)}MB)')),
        );
        return;
      }

      setState(() => _pendingFile = file);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick a file: $e')),
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final file = _pendingFile;
    if (text.isEmpty && file == null) return;
    if (_sending) return;

    setState(() => _sending = true);
    _messageController.clear();
    setState(() => _pendingFile = null);

    try {
      Message? newMessage;
      if (file != null) {
        newMessage = await ChatService.sendAttachment(
          widget.partner.id,
          fileName: file.name,
          mimeType: _guessMimeType(file.extension),
          fileBytes: Uint8List.fromList(file.bytes!),
          caption: text.isEmpty ? null : text,
        );
      } else {
        newMessage = await ChatService.sendMessage(widget.partner.id, text);
      }

      if (newMessage != null) {
        setState(() {
          _messages.add(newMessage!);
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;
      final message = e is RecipientKeyUnavailableException
          ? e.toString()
          : 'Failed to send message: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  static String _guessMimeType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  /// A message ends its visual group when it's the last message, the next
  /// message is from a different sender, or more than 3 minutes separate
  /// them from the next one.
  bool _isGroupEnd(int index) {
    if (index == _messages.length - 1) return true;
    final current = _messages[index];
    final next = _messages[index + 1];
    if (current.sender.id != next.sender.id) return true;
    return next.timestamp.difference(current.timestamp) > const Duration(minutes: 3);
  }

  /// A day divider is shown above the first message of each calendar day.
  bool _isNewDay(int index) {
    if (index == 0) return true;
    final previous = _messages[index - 1].timestamp.toLocal();
    final current = _messages[index].timestamp.toLocal();
    return previous.year != current.year || previous.month != current.month || previous.day != current.day;
  }

  @override
  Widget build(BuildContext context) {
    final online = _livePartner.isOnline;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            _HeaderAvatar(name: _livePartner.name, online: online),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _livePartner.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.title.copyWith(fontSize: 16),
                  ),
                  Text(
                    online ? 'Online' : formatLastSeen(_livePartner.lastActiveAt),
                    style: AppTextStyles.meta.copyWith(
                      fontSize: 11,
                      color: online ? AppColors.onlineAccent : AppColors.textTertiary,
                      fontWeight: online ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_outline, size: 20),
            tooltip: 'End-to-end encrypted',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Messages in this conversation are end-to-end encrypted.')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          if (_pendingFile != null) _buildPendingAttachment(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.white),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline, color: AppColors.grey600, size: 36),
            const SizedBox(height: 12),
            Text('No messages yet', style: AppTextStyles.title.copyWith(fontSize: 15)),
            const SizedBox(height: 4),
            Text('Say hi to ${widget.partner.name}', style: AppTextStyles.meta),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message.sender.email == _currentUserEmail;

        final bubble = MessageBubble(
          message: message,
          isMe: isMe,
          isGroupEnd: _isGroupEnd(index),
        );

        if (!_isNewDay(index)) return bubble;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DayDivider(date: message.timestamp),
            bubble,
          ],
        );
      },
    );
  }

  Widget _buildPendingAttachment() {
    final file = _pendingFile!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.insert_drive_file_outlined, size: 16, color: AppColors.grey300),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.grey500),
            onPressed: () => setState(() => _pendingFile = null),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.only(left: 4, right: 8, top: 10, bottom: 10),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file, color: AppColors.grey400),
              onPressed: _sending ? null : _pickAttachment,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Message...',
                  hintStyle: const TextStyle(color: AppColors.grey500),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceRaised,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                style: AppTextStyles.body,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            _SendButton(onTap: _sending ? null : _sendMessage, loading: _sending),
          ],
        ),
      ),
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  const _HeaderAvatar({required this.name, required this.online});

  final String name;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceRaised,
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: AppTextStyles.title.copyWith(fontSize: 14),
            ),
          ),
          if (online)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.onlineAccent,
                  border: Border.all(color: AppColors.background, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final local = date.toLocal();
    final today = DateTime.now();
    final isToday = local.year == today.year && local.month == today.month && local.day == today.day;
    final label = isToday ? 'Today' : DateFormat('MMMM d').format(local);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Text(label, style: AppTextStyles.meta.copyWith(fontSize: 11)),
        ),
      ),
    );
  }
}

class _SendButton extends StatefulWidget {
  const _SendButton({required this.onTap, this.loading = false});

  final VoidCallback? onTap;
  final bool loading;

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _pressed = true),
      onTapUp: widget.onTap == null ? null : (_) => setState(() => _pressed = false),
      onTapCancel: widget.onTap == null ? null : () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
          ),
          child: widget.loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.black),
                )
              : const Icon(Icons.arrow_upward, color: AppColors.black, size: 20),
        ),
      ),
    );
  }
}
