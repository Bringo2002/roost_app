import 'dart:async';
import 'package:flutter/material.dart';
import 'package:roost_app/models/conversation_summary.dart';
import 'package:roost_app/services/chat_service.dart';
import 'package:roost_app/services/encryption_service.dart';
import 'package:roost_app/pages/chat/chat_room_page.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/theme/app_text_styles.dart';
import 'package:roost_app/widgets/chat/chat_tile.dart';

class ActiveChatsPage extends StatefulWidget {
  const ActiveChatsPage({super.key});

  @override
  State<ActiveChatsPage> createState() => _ActiveChatsPageState();
}

class _ActiveChatsPageState extends State<ActiveChatsPage> {
  List<ConversationSummary> _conversations = [];
  bool _isLoading = true;
  String? _error;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadChats();
    // Poll conversations list every 5 seconds to keep unread badges, last messages, and presence current
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _loadChats(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadChats({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final conversations = await ChatService.getConversations();
      
      // Decrypt previews client-side
      for (final summary in conversations) {
        if (summary.lastMessageContent != null) {
          try {
            final plaintext = await EncryptionService.decryptFrom(
              summary.partner.id,
              summary.lastMessageContent!,
              summary.lastMessageNonce,
            );
            
            // Format preview: "You: Hello" or just "Hello"
            final isMe = summary.lastMessageSenderId != summary.partner.id;
            summary.decryptedPreview = isMe ? 'You: $plaintext' : plaintext;
          } catch (_) {
            summary.decryptedPreview = summary.hasAttachment ? '📎 Attachment' : '🔒 Decryption failed';
          }
        } else if (summary.hasAttachment) {
          summary.decryptedPreview = '📎 Attachment';
        } else {
          summary.decryptedPreview = 'No messages yet';
        }
      }

      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _confirmDeleteChat(ConversationSummary summary) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete this chat?', style: TextStyle(color: Colors.white, fontSize: 18)),
        content: Text(
          'This removes ${summary.partner.name} from your chat list. '
          'It\'ll reappear if they message you again.',
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm != true) return false;

    final success = await ChatService.deleteChat(summary.partner.id);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete chat. Please try again.')),
      );
    }
    return success;
  }

  @override
  Widget build(BuildContext context) {
    return _buildBody();
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.white),
      );
    }

    if (_error != null) {
      return _StateMessage(
        icon: Icons.error_outline,
        title: "Couldn't load your messages",
        subtitle: _error!,
        action: ElevatedButton(
          onPressed: _loadChats,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.white,
            foregroundColor: AppColors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text('Retry'),
        ),
      );
    }

    if (_conversations.isEmpty) {
      return const _StateMessage(
        icon: Icons.chat_bubble_outline,
        title: 'No conversations yet',
        subtitle: 'Messages with landlords and tenants will show up here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChats,
      color: AppColors.black,
      backgroundColor: AppColors.white,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _conversations.length,
        separatorBuilder: (_, _) => const Divider(
          height: 1,
          indent: 20,
          endIndent: 20,
          color: AppColors.divider,
        ),
        itemBuilder: (context, index) {
          final summary = _conversations[index];
          return Dismissible(
            key: ValueKey(summary.partner.id),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.redAccent,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: const Icon(Icons.delete_outline, color: Colors.white),
            ),
            confirmDismiss: (_) => _confirmDeleteChat(summary),
            onDismissed: (_) {
              setState(() {
                _conversations.removeAt(index);
              });
            },
            child: ChatTile(
              summary: summary,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatRoomPage(partner: summary.partner),
                  ),
                ).then((_) => _loadChats());
              },
            ),
          );
        },
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.grey600, size: 40),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.title,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.meta,
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
