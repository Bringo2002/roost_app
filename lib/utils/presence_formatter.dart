import 'package:intl/intl.dart';

/// Formats a "last seen" label for a chat partner's [lastActiveAt].
/// Callers should check `User.isOnline` first and show "Online" instead
/// of calling this when that's true.
String formatLastSeen(DateTime? lastActiveAt) {
  if (lastActiveAt == null) return '';

  final local = lastActiveAt.toLocal();
  final now = DateTime.now();
  final diff = now.difference(local);

  if (diff.inMinutes < 1) return 'Last seen just now';
  if (diff.inMinutes < 60) return 'Last seen ${diff.inMinutes}m ago';

  final isToday = local.year == now.year && local.month == now.month && local.day == now.day;
  if (isToday) return 'Last seen today at ${DateFormat('h:mm a').format(local)}';

  final yesterday = now.subtract(const Duration(days: 1));
  final isYesterday = local.year == yesterday.year && local.month == yesterday.month && local.day == yesterday.day;
  if (isYesterday) return 'Last seen yesterday at ${DateFormat('h:mm a').format(local)}';

  return 'Last seen ${DateFormat('MMM d').format(local)}';
}
