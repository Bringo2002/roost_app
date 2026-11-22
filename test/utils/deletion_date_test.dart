import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/utils/deletion_date.dart';

void main() {
  test('formats the day with the full month name', () {
    // Built as a local time so the conversion is a no-op on any machine.
    expect(formatDeletionDate(DateTime(2026, 12, 5, 12)), '5 December 2026');
  });

  test('does not pad single-digit days', () {
    expect(formatDeletionDate(DateTime(2027, 1, 3, 12)), '3 January 2027');
  });
}
