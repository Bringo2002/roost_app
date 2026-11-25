import 'package:flutter/material.dart';
import 'package:roost_app/models/report_reason.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/theme/app_colors.dart';

/// Bottom sheet for reporting another user: pick a reason, add an optional
/// note, send.
///
/// The sheet does not talk to the backend itself. [onSubmit] does the work and
/// throws on failure; the sheet then stays open and shows the error so the
/// person can retry or cancel.
class ReportUserSheet extends StatefulWidget {
  const ReportUserSheet({super.key, required this.userName, required this.onSubmit});

  /// Who is being reported, shown in the title.
  final String userName;

  /// Files the report. [note] is already trimmed and is null when blank.
  final Future<void> Function(ReportReason reason, String? note) onSubmit;

  /// Shows the sheet. Completes with true once the report was sent, false when
  /// cancelled, and null when dismissed by tapping outside or swiping down.
  static Future<bool?> show(
    BuildContext context, {
    required String userName,
    required Future<void> Function(ReportReason reason, String? note) onSubmit,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ReportUserSheet(userName: userName, onSubmit: onSubmit),
    );
  }

  @override
  State<ReportUserSheet> createState() => _ReportUserSheetState();
}

class _ReportUserSheetState extends State<ReportUserSheet> {
  final _noteController = TextEditingController();
  ReportReason? _reason;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _submitting) return;
    final trimmed = _noteController.text.trim();

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onSubmit(reason, trimmed.isEmpty ? null : trimmed);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toUserMessage('Could not send your report. Please try again.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Report ${widget.userName}',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Why are you reporting them? Our team reviews every report.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 8),
              for (final reason in ReportReason.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    _reason == reason ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: _reason == reason ? Colors.white : Colors.grey,
                  ),
                  title: Text(reason.label, style: const TextStyle(color: Colors.white, fontSize: 15)),
                  onTap: _submitting ? null : () => setState(() => _reason = reason),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                enabled: !_submitting,
                maxLength: kMaxReportNoteLength,
                maxLines: 3,
                minLines: 2,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Add details (optional)',
                  hintStyle: TextStyle(color: Colors.grey),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.destructive, fontSize: 13)),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _submitting ? null : () => Navigator.pop(context, false),
                      child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const Key('report-submit-button'),
                      onPressed: _reason == null || _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Send report'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
