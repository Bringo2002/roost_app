import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
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
  final TextEditingController _searchController = TextEditingController();

  List<Message> _messages = [];
  bool _isLoading = true;
  String? _currentUserEmail;
  Timer? _pollingTimer;
  late User _livePartner = widget.partner;

  PlatformFile? _pendingFile;
  bool _sending = false;

  // Telegram Messaging features
  Message? _replyToMessage;
  Message? _editMessage;
  bool _partnerIsTyping = false;
  int? _firstUnreadMessageId;
  DateTime? _lastTypingSentTime;

  // Voice message recorder features
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _recordTimer;

  // Search feature
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _pollingTimer?.cancel();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
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

    // Poll for new messages, presence and typing status every 5 seconds.
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        _loadMessages(silent: true);
        _refreshPresence();
        _checkTypingStatus();
      }
    });
  }

  Future<void> _refreshPresence() async {
    final updated = await ChatService.getUserProfile(widget.partner.id);
    if (updated != null && mounted) {
      setState(() => _livePartner = updated);
    }
  }

  Future<void> _checkTypingStatus() async {
    final typing = await ChatService.getTypingStatus(widget.partner.id);
    if (mounted && typing != _partnerIsTyping) {
      setState(() {
        _partnerIsTyping = typing;
      });
    }
  }

  void _onTextChanged(String text) {
    if (text.isEmpty) return;
    final now = DateTime.now();
    if (_lastTypingSentTime == null || now.difference(_lastTypingSentTime!) > const Duration(seconds: 3)) {
      _lastTypingSentTime = now;
      ChatService.sendTyping(widget.partner.id);
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

      // Determine first unread message ID on initial load
      if (_firstUnreadMessageId == null) {
        for (final m in messages) {
          final isMe = m.sender.email == _currentUserEmail;
          if (!isMe && !m.read) {
            _firstUnreadMessageId = m.id;
            break;
          }
        }
      }

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
    final replyId = _replyToMessage?.id;
    final editMsg = _editMessage;

    if (text.isEmpty && file == null) return;
    if (_sending) return;

    setState(() {
      _sending = true;
      _pendingFile = null;
      _replyToMessage = null;
      _editMessage = null;
    });
    _messageController.clear();

    try {
      if (editMsg != null) {
        final updated = await ChatService.editMessage(
          editMsg.id,
          widget.partner.id,
          text,
        );
        if (updated != null) {
          setState(() {
            final idx = _messages.indexWhere((m) => m.id == editMsg.id);
            if (idx != -1) {
              _messages[idx] = updated;
            }
          });
        }
      } else {
        Message? newMessage;
        if (file != null) {
          newMessage = await ChatService.sendAttachment(
            widget.partner.id,
            fileName: file.name,
            mimeType: _guessMimeType(file.extension),
            fileBytes: Uint8List.fromList(file.bytes!),
            caption: text.isEmpty ? null : text,
            replyToMessageId: replyId,
          );
        } else {
          newMessage = await ChatService.sendMessage(
            widget.partner.id,
            text,
            replyToMessageId: replyId,
          );
        }

        if (newMessage != null) {
          setState(() {
            _messages.add(newMessage!);
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _setReplyMessage(Message message) {
    setState(() {
      _editMessage = null;
      _replyToMessage = message;
    });
  }

  void _setEditMessage(Message message) {
    setState(() {
      _replyToMessage = null;
      _editMessage = message;
      _messageController.text = message.content;
    });
  }

  void _cancelReplyOrEdit() {
    setState(() {
      _replyToMessage = null;
      _editMessage = null;
      _messageController.clear();
    });
  }

  Future<void> _toggleReaction(Message message, String emoji) async {
    try {
      final res = await ChatService.toggleReaction(message.id, emoji);
      if (res != null) {
        _loadMessages(silent: true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update reaction: $e')),
      );
    }
  }

  Future<void> _deleteMessage(Message message) async {
    try {
      final success = await ChatService.deleteMessage(message.id);
      if (success) {
        setState(() {
          _messages.removeWhere((m) => m.id == message.id);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete message: $e')),
      );
    }
  }

  void _showForwardSheet(Message message) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.white),
      ),
    );

    List<User> partners = [];
    try {
      partners = await ChatService.getActiveChats();
    } catch (_) {}

    if (!mounted) return;
    Navigator.pop(context); // Dismiss loading dialog

    if (partners.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active chats to forward to')),
      );
      return;
    }

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Forward to...',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: partners.length,
                  itemBuilder: (context, index) {
                    final partner = partners[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.surfaceRaised,
                        child: Text(
                          partner.name.isNotEmpty ? partner.name[0].toUpperCase() : '?',
                          style: const TextStyle(color: AppColors.white),
                        ),
                      ),
                      title: Text(partner.name, style: const TextStyle(color: AppColors.white)),
                      subtitle: Text(
                        partner.role.toUpperCase(),
                        style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        _forwardMessageTo(message, partner);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _forwardMessageTo(Message message, User partner) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.white),
      ),
    );

    try {
      Message? forwarded;
      if (message.hasAttachment) {
        if (message.attachmentBytes == null) {
          throw Exception('Attachment bytes not loaded yet');
        }
        forwarded = await ChatService.forwardAttachmentMessage(
          partner.id,
          fileBytes: message.attachmentBytes!,
          fileName: message.attachmentFileName ?? 'file',
          mimeType: message.attachmentMimeType ?? 'application/octet-stream',
          caption: message.content.isEmpty ? null : message.content,
        );
      } else {
        forwarded = await ChatService.forwardTextMessage(partner.id, message.content);
      }

      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading dialog

      if (forwarded != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Message forwarded to ${partner.name}!')),
        );
      } else {
        throw Exception('Forward request returned null');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to forward message: $e')),
      );
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _recordDuration = 0;
        });

        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordDuration++;
          });
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start recording: $e')),
      );
    }
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    _recordTimer?.cancel();
    _recordTimer = null;

    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });

      if (cancel || path == null) {
        if (path != null) {
          try {
            File(path).delete();
          } catch (_) {}
        }
        return;
      }

      final file = File(path);
      final bytes = await file.readAsBytes();

      if (bytes.isNotEmpty) {
        setState(() => _sending = true);
        final newMessage = await ChatService.sendAttachment(
          widget.partner.id,
          fileName: 'voice_message.m4a',
          mimeType: 'audio/m4a',
          fileBytes: bytes,
        );
        if (newMessage != null && mounted) {
          setState(() {
            _messages.add(newMessage);
          });
          _scrollToBottom();
        }
      }
      try {
        file.delete();
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save recording: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _formatRecordDuration(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  Message? _findMessageById(int? id) {
    if (id == null) return null;
    for (final msg in _messages) {
      if (msg.id == id) return msg;
    }
    return null;
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
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  bool _isDisplayGroupEnd(List<Message> list, int index) {
    if (index == list.length - 1) return true;
    final current = list[index];
    final next = list[index + 1];
    if (current.sender.id != next.sender.id) return true;
    return next.timestamp.difference(current.timestamp) > const Duration(minutes: 3);
  }

  bool _isDisplayNewDay(List<Message> list, int index) {
    if (index == 0) return true;
    final previous = list[index - 1].timestamp.toLocal();
    final current = list[index].timestamp.toLocal();
    return previous.year != current.year || previous.month != current.month || previous.day != current.day;
  }

  Widget? _buildAppBarTitle() {
    if (_isSearching) {
      return TextField(
        controller: _searchController,
        style: const TextStyle(color: AppColors.white, fontSize: 16),
        decoration: const InputDecoration(
          hintText: 'Search messages...',
          hintStyle: TextStyle(color: AppColors.grey500),
          border: InputBorder.none,
        ),
        autofocus: true,
        onChanged: (val) {
          setState(() {
            _searchQuery = val.trim();
          });
        },
      );
    }

    final online = _livePartner.isOnline;
    return Row(
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
                _partnerIsTyping
                    ? 'typing...'
                    : (online ? 'Online' : formatLastSeen(_livePartner.lastActiveAt)),
                style: AppTextStyles.meta.copyWith(
                  fontSize: 11,
                  color: _partnerIsTyping
                      ? AppColors.white
                      : (online ? AppColors.onlineAccent : AppColors.textTertiary),
                  fontWeight: (_partnerIsTyping || online) ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _buildAppBarTitle(),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.search, size: 20),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.lock_outline, size: 20),
              tooltip: 'End-to-end encrypted',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Messages in this conversation are end-to-end encrypted.')),
                );
              },
            ),
          ]
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          if (_pendingFile != null) _buildPendingAttachment(),
          _buildComposerHeader(),
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

    final displayMessages = _searchQuery.isEmpty
        ? _messages
        : _messages.where((m) => m.content.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    if (displayMessages.isEmpty) {
      return const Center(
        child: Text('No matching messages found', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: displayMessages.length,
      itemBuilder: (context, index) {
        final message = displayMessages[index];
        final isMe = message.sender.email == _currentUserEmail;
        final replyMsg = _findMessageById(message.replyToMessageId);

        final bubble = MessageBubble(
          key: ValueKey(message.id),
          message: message,
          isMe: isMe,
          isGroupEnd: _isDisplayGroupEnd(displayMessages, index),
          replyMessage: replyMsg,
          onReply: () => _setReplyMessage(message),
          onEdit: () => _setEditMessage(message),
          onDelete: () => _deleteMessage(message),
          onReact: (emoji) => _toggleReaction(message, emoji),
          onForward: () => _showForwardSheet(message),
        );

        final isFirstUnread = message.id == _firstUnreadMessageId;
        final isNewDay = _isDisplayNewDay(displayMessages, index);

        Widget result = bubble;
        if (isNewDay) {
          result = Column(
            key: ValueKey('day-${message.id}'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DayDivider(date: message.timestamp),
              if (isFirstUnread) _NewMessagesDivider(),
              bubble,
            ],
          );
        } else if (isFirstUnread) {
          result = Column(
            key: ValueKey('unread-${message.id}'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _NewMessagesDivider(),
              bubble,
            ],
          );
        }

        return result;
      },
    );
  }

  Widget _buildComposerHeader() {
    if (_replyToMessage == null && _editMessage == null) return const SizedBox.shrink();

    final isEdit = _editMessage != null;
    final senderName = isEdit
        ? 'Edit Message'
        : (_replyToMessage!.sender.email == _currentUserEmail ? 'You' : _replyToMessage!.sender.name);
    final text = isEdit
        ? _editMessage!.content
        : (_replyToMessage!.content.isNotEmpty ? _replyToMessage!.content : (_replyToMessage!.hasAttachment ? '📎 Attachment' : ''));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(
          top: BorderSide(color: AppColors.divider),
          left: BorderSide(color: AppColors.white, width: 3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isEdit ? Icons.edit_outlined : Icons.reply,
            color: AppColors.white,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  senderName,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.grey500),
            onPressed: _cancelReplyOrEdit,
          ),
        ],
      ),
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
    if (_isRecording) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => _stopRecording(cancel: true),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    const _FlashingDot(),
                    const SizedBox(width: 8),
                    Text(
                      'Recording: ${_formatRecordDuration(_recordDuration)}',
                      style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send, color: AppColors.white),
                onPressed: () => _stopRecording(cancel: false),
              ),
            ],
          ),
        ),
      );
    }

    final hasTextOrFile = _messageController.text.trim().isNotEmpty || _pendingFile != null;

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
                onChanged: (val) {
                  _onTextChanged(val);
                  setState(() {}); // Updates send/mic toggle dynamically
                },
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
            if (hasTextOrFile)
              _SendButton(onTap: _sending ? null : _sendMessage, loading: _sending)
            else
              IconButton(
                icon: const Icon(Icons.mic, color: AppColors.white),
                onPressed: _sending ? null : _startRecording,
              ),
          ],
        ),
      ),
    );
  }
}

class _FlashingDot extends StatefulWidget {
  const _FlashingDot();

  @override
  State<_FlashingDot> createState() => _FlashingDotState();
}

class _FlashingDotState extends State<_FlashingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
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

class _NewMessagesDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppColors.white.withValues(alpha: 0.15))),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'NEW MESSAGES',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
          Expanded(child: Divider(color: AppColors.white.withValues(alpha: 0.15))),
        ],
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
