import 'package:intl/intl.dart';

/// Formats the day an account will be deleted, in the user's local time,
/// e.g. `5 December 2026`.
String formatDeletionDate(DateTime when) {
  return DateFormat('d MMMM yyyy').format(when.toLocal());
}
