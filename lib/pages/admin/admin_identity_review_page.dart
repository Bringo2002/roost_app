import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:roost_app/models/identity_review.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/identity_review_service.dart';
import 'package:roost_app/theme/app_colors.dart';

const _kCardRadius = 16.0;
const _kImageHeight = 320.0;

// ──────────────────────────────────────────────────────────────────────────────
// Queue
// ──────────────────────────────────────────────────────────────────────────────

/// Admin-only queue of listers whose identity documents are waiting for a
/// decision. Tapping a lister opens [IdentityReviewDetailPage].
class AdminIdentityReviewPage extends StatefulWidget {
  const AdminIdentityReviewPage({super.key});

  @override
  State<AdminIdentityReviewPage> createState() => _AdminIdentityReviewPageState();
}

class _AdminIdentityReviewPageState extends State<AdminIdentityReviewPage> {
  List<IdentityReview> _reviews = [];
  bool _loading = true;
  String? _error;

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
      final reviews = await IdentityReviewService.pending();
      if (!mounted) return;
      setState(() {
        _reviews = reviews;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toUserMessage();
      });
    }
  }

  Future<void> _open(IdentityReview review) async {
    final decided = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => IdentityReviewDetailPage(review: review)),
    );
    if (decided == true && mounted) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Identity Verifications'),
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: _reviews.isEmpty
          ? ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No identity documents waiting for review.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            )
          : ListView.separated(
              itemCount: _reviews.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.divider),
              itemBuilder: (context, index) {
                final review = _reviews[index];
                final count = review.documents.length;
                return ListTile(
                  leading: const Icon(Icons.badge_outlined, color: AppColors.white),
                  title: Text(
                    review.name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    count == 1 ? '1 document' : '$count documents',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () => _open(review),
                );
              },
            ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Detail
// ──────────────────────────────────────────────────────────────────────────────

/// Shows one lister's identity documents and lets the admin accept or reject
/// them. Pops with `true` once a decision has been recorded.
class IdentityReviewDetailPage extends StatefulWidget {
  const IdentityReviewDetailPage({super.key, required this.review});

  final IdentityReview review;

  @override
  State<IdentityReviewDetailPage> createState() => _IdentityReviewDetailPageState();
}

class _IdentityReviewDetailPageState extends State<IdentityReviewDetailPage> {
  bool _busy = false;

  Future<void> _accept() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accept these documents?'),
        content: Text('${widget.review.name} will be marked as identity verified.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, accept')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    await _decide(() => IdentityReviewService.accept(widget.review.userId));
  }

  Future<void> _reject() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => const _RejectDialog(),
    );
    if (reason == null) return;
    if (!mounted) return;
    await _decide(() => IdentityReviewService.reject(widget.review.userId, reason));
  }

  Future<void> _decide(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toUserMessage())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(review.name),
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Check that the name and details on the document match this account, '
            'and that the photo is clear and unaltered.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          for (final document in review.documents) ...[
            _DocumentCard(document: document),
            const SizedBox(height: 16),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _reject,
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _accept,
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Reject dialog
// ──────────────────────────────────────────────────────────────────────────────

/// Asks for the reason a rejection is sent with. Pops the trimmed reason, or
/// null if the admin cancels. The send button stays off until there is one.
class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _controller.text.trim().isNotEmpty;
    return AlertDialog(
      title: const Text('Reject documents'),
      content: TextField(
        controller: _controller,
        maxLength: 1000,
        maxLines: 4,
        autofocus: true,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          labelText: 'Reason for the lister',
          helperText: 'Tell them what to fix, e.g. the photo is blurry.',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: canSend ? () => Navigator.pop(context, _controller.text.trim()) : null,
          child: const Text('Send rejection'),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Document card
// ──────────────────────────────────────────────────────────────────────────────

/// One document: fetched when the card appears, kept only in memory, shown
/// zoomable if it is an image. A PDF is written to a temporary file to open it
/// in a viewer, and that file is deleted when the screen closes.
class _DocumentCard extends StatefulWidget {
  const _DocumentCard({required this.document});

  final IdentityDocument document;

  @override
  State<_DocumentCard> createState() => _DocumentCardState();
}

class _DocumentCardState extends State<_DocumentCard> {
  Uint8List? _bytes;
  bool _loading = true;
  String? _error;
  File? _tempPdf;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _tempPdf?.delete().ignore();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bytes = await IdentityReviewService.file(widget.document.id);
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toUserMessage();
      });
    }
  }

  Future<void> _openPdf(Uint8List bytes) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/identity_review_${widget.document.id}.pdf');
      await file.writeAsBytes(bytes, flush: true);
      _tempPdf = file;
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done && mounted) {
        _snack(result.message);
      }
    } catch (_) {
      if (mounted) _snack('Could not open the PDF.');
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final document = widget.document;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(_kCardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            document.label,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          if (document.wasRejected) ...[
            const SizedBox(height: 6),
            Text(
              'Rejected earlier: ${document.rejectReason ?? 'no reason recorded'}. '
              'Accepting is refused until the lister replaces it.',
              style: const TextStyle(color: AppColors.warning, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          _buildContent(document),
        ],
      ),
    );
  }

  Widget _buildContent(IdentityDocument document) {
    if (_loading) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final bytes = _bytes;
    if (_error != null || bytes == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_error ?? 'The file could not be loaded.', style: const TextStyle(color: Colors.white70)),
          TextButton(onPressed: _fetch, child: const Text('Retry')),
        ],
      );
    }
    if (document.isImage) {
      return SizedBox(
        height: _kImageHeight,
        width: double.infinity,
        child: InteractiveViewer(
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Text('This image could not be shown.', style: TextStyle(color: Colors.white70)),
            ),
          ),
        ),
      );
    }
    if (document.isPdf) {
      return Row(
        children: [
          const Icon(Icons.picture_as_pdf_outlined, color: Colors.white70),
          const SizedBox(width: 8),
          const Expanded(child: Text('PDF document', style: TextStyle(color: Colors.white70))),
          FilledButton.tonal(
            onPressed: () => _openPdf(bytes),
            child: const Text('Open PDF'),
          ),
        ],
      );
    }
    return const Text('This file type can\'t be previewed.', style: TextStyle(color: Colors.white70));
  }
}
