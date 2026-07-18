import 'dart:async';
import 'package:flutter/material.dart';
import 'package:roost_app/models/user.dart';
import 'package:roost_app/models/message.dart';
import 'package:roost_app/services/chat_service.dart';
import 'package:roost_app/services/auth_service.dart';
import 'package:roost_app/services/encryption_service.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/theme/app_text_styles.dart';
import 'package:roost_app/theme/app_theme.dart';
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

    // Poll for new messages every 5 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        _loadMessages(silent: true);
      }
    });
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

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    try {
      final newMessage = await ChatService.sendMessage(widget.partner.id, text);
      if (newMessage != null) {
        setState(() {
          _messages.add(newMessage);
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
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            _HeaderAvatar(name: widget.partner.name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.partner.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.title.copyWith(fontSize: 16),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 11, color: AppColors.grey500),
                      const SizedBox(width: 4),
                      Text('End-to-end encrypted', style: AppTextStyles.meta.copyWith(fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadMessages(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
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
          content: message.content,
          timestamp: message.timestamp,
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

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 8, top: 10, bottom: 10),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
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
            _SendButton(onTap: _sendMessage),
          ],
        ),
      ),
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  const _HeaderAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
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
  const _SendButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
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
          child: const Icon(Icons.arrow_upward, color: AppColors.black, size: 20),
        ),
      ),
    );
  }
}
