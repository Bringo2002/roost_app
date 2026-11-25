import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/models/report_reason.dart';

void main() {
  test('the wire values are exactly the reasons the backend accepts', () {
    // Mirrors UserReport.Reason in the Roost backend; the database refuses
    // anything else, so a drift here would turn every report into a 400.
    expect(
      ReportReason.values.map((r) => r.apiValue).toList(),
      ['SPAM', 'HARASSMENT', 'INAPPROPRIATE_CONTENT', 'SCAM_OR_FRAUD', 'OTHER'],
    );
  });

  test('every reason has a readable label', () {
    for (final reason in ReportReason.values) {
      expect(reason.label.trim(), isNotEmpty);
    }
  });

  test('the note limit matches the backend', () {
    expect(kMaxReportNoteLength, 500);
  });
}
