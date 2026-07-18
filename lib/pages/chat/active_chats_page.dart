import 'package:flutter/material.dart';
import 'package:roost_app/models/user.dart';
import 'package:roost_app/services/chat_service.dart';
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
  List<User> _partners = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final partners = await ChatService.getActiveChats();
      if (!mounted) return;
      setState(() {
        _partners = partners;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MESSAGES')),
      body: _buildBody(),
    );
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

    if (_partners.isEmpty) {
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
        itemCount: _partners.length,
        separatorBuilder: (_, _) => const Divider(
          height: 1,
          indent: 20,
          endIndent: 20,
          color: AppColors.divider,
        ),
        itemBuilder: (context, index) {
          final partner = _partners[index];
          return ChatTile(
            partner: partner,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatRoomPage(partner: partner),
                ),
              ).then((_) => _loadChats());
            },
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
