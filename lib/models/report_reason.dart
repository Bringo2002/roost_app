/// Longest note the backend accepts with a report.
const int kMaxReportNoteLength = 500;

/// Why someone is reporting another user.
///
/// [apiValue] is the exact name the backend's `UserReport.Reason` enum
/// accepts; [label] is what the person sees when choosing.
enum ReportReason {
  spam('SPAM', 'Spam'),
  harassment('HARASSMENT', 'Harassment or abuse'),
  inappropriateContent('INAPPROPRIATE_CONTENT', 'Inappropriate content'),
  scamOrFraud('SCAM_OR_FRAUD', 'Scam or fraud'),
  other('OTHER', 'Something else');

  const ReportReason(this.apiValue, this.label);

  /// The value sent to the backend.
  final String apiValue;

  /// The text shown to the person reporting.
  final String label;
}
