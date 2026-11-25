import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:roost_app/models/blocked_user.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/user_safety_service.dart';
import 'package:roost_app/theme/app_colors.dart';

/// The people the signed-in user has blocked, each with an Unblock button.
class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  List<BlockedUser> _users = const [];
  bool _loading = true;
  String? _error;

  /// Ids with an unblock request in flight, so a double tap sends one request.
  final Set<int> _unblocking = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await UserSafetyService.blockedUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toUserMessage('Could not load your blocked users. Please try again.');
        _loading = false;
      });
    }
  }

  Future<void> _unblock(BlockedUser user) async {
    if (_unblocking.contains(user.id)) return;
    setState(() => _unblocking.add(user.id));
    try {
      await UserSafetyService.unblock(user.id);
      if (!mounted) return;
      setState(() => _users = _users.where((u) => u.id != user.id).toList(growable: false));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.displayName} unblocked')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toUserMessage('Could not unblock this user. Please try again.'))),
      );
    } finally {
      if (mounted) setState(() => _unblocking.remove(user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked users')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.white));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                key: const Key('blocked-retry-button'),
                onPressed: _load,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    if (_users.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "You haven't blocked anyone.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'People you block can\'t message you, and you won\'t see their messages. '
                'You can block someone from the menu in a chat.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: _users.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.divider),
      itemBuilder: (context, index) {
        final user = _users[index];
        final busy = _unblocking.contains(user.id);
        return ListTile(
          leading: _Avatar(user: user),
          title: Text(user.displayName, style: const TextStyle(color: Colors.white, fontSize: 15)),
          subtitle: Text(
            'Blocked ${DateFormat.yMMMd().format(user.blockedAt.toLocal())}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          trailing: OutlinedButton(
            key: Key('unblock-${user.id}'),
            onPressed: busy ? null : () => _unblock(user),
            child: const Text('Unblock'),
          ),
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});

  final BlockedUser user;

  @override
  Widget build(BuildContext context) {
    const size = 40.0;
    final url = user.avatarUrl;
    final placeholder = CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.surfaceContainerHigh,
      child: Text(user.initial, style: const TextStyle(color: Colors.white)),
    );
    if (url == null || url.isEmpty) return placeholder;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => placeholder,
      ),
    );
  }
}
