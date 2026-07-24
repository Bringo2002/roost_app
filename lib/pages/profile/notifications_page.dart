import 'package:flutter/material.dart';
import 'package:roost_app/services/push_notification_service.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/pages/search/property_detail_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<NotificationItem> _notifications = [];
  bool _showOnlyUnread = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    setState(() {
      _notifications = PushNotificationService.getNotifications();
    });
  }

  Future<void> _markAllRead() async {
    await PushNotificationService.markAllAsRead();
    _loadNotifications();
  }

  Future<void> _clearAll() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear All Notifications?', style: TextStyle(color: Colors.white, fontSize: 18)),
        content: const Text(
          'Are you sure you want to remove all notification history?',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await PushNotificationService.clearAll();
      _loadNotifications();
    }
  }

  Future<void> _onNotificationTap(NotificationItem item) async {
    await PushNotificationService.markAsRead(item.id);
    _loadNotifications();

    if (!mounted) return;

    // Handle deep payload navigation if available
    final payload = item.payload;
    if (payload != null && payload.containsKey('propertyId')) {
      final propId = payload['propertyId'];
      try {
        final res = await ApiService.get('/api/properties/$propId');
        if (!mounted) return;
        final property = Property.fromJson(res);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PropertyDetailPage(property: property)),
        );
      } catch (_) {}
    }
  }

  String _formatTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;
    final displayList = _showOnlyUnread
        ? _notifications.where((n) => !n.isRead).toList()
        : _notifications;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notifications',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              unreadCount == 0 ? 'All caught up' : '$unreadCount unread',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
        actions: [
          if (unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all_rounded, color: Colors.white),
              tooltip: 'Mark all as read',
              onPressed: _markAllRead,
            ),
          if (_notifications.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              color: const Color(0xFF1C1C1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (val) {
                if (val == 'mark_read') _markAllRead();
                if (val == 'clear_all') _clearAll();
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'mark_read',
                  child: Row(
                    children: [
                      Icon(Icons.done_all_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text('Mark all read', style: TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 20),
                      SizedBox(width: 10),
                      Text('Clear all', style: TextStyle(color: Colors.redAccent, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          if (_notifications.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildFilterTab(
                    label: 'All (${_notifications.length})',
                    selected: !_showOnlyUnread,
                    onTap: () => setState(() => _showOnlyUnread = false),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterTab(
                    label: 'Unread ($unreadCount)',
                    selected: _showOnlyUnread,
                    onTap: () => setState(() => _showOnlyUnread = true),
                  ),
                ],
              ),
            ),

          Expanded(
            child: displayList.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 30),
                    itemCount: displayList.length,
                    itemBuilder: (context, index) {
                      final item = displayList[index];
                      return Dismissible(
                        key: Key('notif-${item.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
                        ),
                        onDismissed: (_) async {
                          final list = PushNotificationService.getNotifications();
                          final target = list.firstWhere((n) => n.id == item.id, orElse: () => item);
                          await PushNotificationService.markAsRead(target.id);
                          _loadNotifications();
                        },
                        child: _buildNotificationTile(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab({required String label, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.grey[400],
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationTile(NotificationItem item) {
    IconData icon;
    Color iconBg;

    switch (item.type) {
      case 'chat':
        icon = Icons.chat_bubble_outline_rounded;
        iconBg = const Color(0xFF1D85FC);
        break;
      case 'booking':
        icon = Icons.calendar_today_rounded;
        iconBg = const Color(0xFF34C759);
        break;
      case 'listing':
        icon = Icons.home_outlined;
        iconBg = const Color(0xFFFF9500);
        break;
      case 'system':
      default:
        icon = Icons.notifications_none_rounded;
        iconBg = const Color(0xFFAF52DE);
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: item.isRead ? const Color(0xFF1C1C1E) : const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isRead ? Colors.transparent : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: InkWell(
        onTap: () => _onNotificationTap(item),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Badge
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBg.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconBg, size: 20),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          _formatTimestamp(item.timestamp),
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: TextStyle(
                        color: item.isRead ? Colors.grey[400] : Colors.grey[200],
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              // Unread Blue Dot
              if (!item.isRead)
                Container(
                  margin: const EdgeInsets.only(left: 8, top: 4),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1D85FC),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Icon(Icons.notifications_off_outlined, color: Colors.grey[600], size: 38),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Notifications',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _showOnlyUnread
                ? 'You have no unread notifications.'
                : 'Updates about your inquiries, bookings, and saved listings will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }
}
