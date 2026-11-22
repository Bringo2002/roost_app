import 'package:flutter/material.dart';
import 'package:roost_app/models/account_deletion_status.dart';
import 'package:roost_app/services/account_deletion_service.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/utils/deletion_date.dart';

/// Lets a signed-in user ask for their account to be deleted.
///
/// The user confirms by typing their account email. Accounts created with a
/// password also re-enter it ([requiresPassword]); accounts created through
/// Google or Apple sign-in have none. The backend schedules the deletion
/// after a grace period, so on success this page shows the date and a Done
/// button. Done pops with `true`, which tells the caller to sign the user out.
class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({
    super.key,
    required this.email,
    required this.requiresPassword,
  });

  /// The signed-in account's email, which the user must type to confirm.
  final String email;

  /// Whether the account has a password to re-enter.
  final bool requiresPassword;

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _submitting = false;
  String? _errorMessage;
  AccountDeletionStatus? _scheduled;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final status = await AccountDeletionService.request(
        email: _emailCtrl.text.trim(),
        password: widget.requiresPassword ? _passwordCtrl.text : null,
      );
      if (!mounted) return;
      setState(() {
        _scheduled = status;
        _submitting = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toUserMessage();
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheduled = _scheduled;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: scheduled == null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text(
          'Delete Account',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: scheduled == null ? _buildForm() : _buildScheduled(scheduled),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(),
          const SizedBox(height: 24),
          if (_errorMessage != null) ...[
            _buildErrorBanner(_errorMessage!),
            const SizedBox(height: 16),
          ],
          _buildLabel('Type your email to confirm'),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('delete-email-field'),
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(hint: widget.email),
            validator: (val) {
              final typed = (val ?? '').trim();
              if (typed.isEmpty) return 'Type your email to confirm';
              if (typed.toLowerCase() != widget.email.trim().toLowerCase()) {
                return 'This does not match your account email';
              }
              return null;
            },
          ),
          if (widget.requiresPassword) ...[
            const SizedBox(height: 20),
            _buildLabel('Password'),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('delete-password-field'),
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(
                hint: 'Your password',
                suffix: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.grey[500],
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Enter your password';
                return null;
              },
            ),
          ],
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              key: const Key('delete-submit-button'),
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.grey[800],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                    )
                  : const Text(
                      'Delete My Account',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildScheduled(AccountDeletionStatus status) {
    final when = status.scheduledAt;
    final message = when != null
        ? 'Your account will be permanently deleted on ${formatDeletionDate(when)}. '
            'Until then you can still log in and cancel the deletion from your profile.'
        : 'Your account has been scheduled for deletion. '
            'Until then you can still log in and cancel the deletion from your profile.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Center(
          child: Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 56),
        ),
        const SizedBox(height: 20),
        const Center(
          child: Text(
            'Deletion scheduled',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[400], fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 36),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            key: const Key('delete-done-button'),
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceContainerHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Delete your Roost account',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'After a short grace period your account is permanently deleted. '
            'You can still log in and cancel during that time.',
            style: TextStyle(color: Colors.grey[400], fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 10),
          for (final line in const [
            'Your profile and personal details are erased.',
            'Your applications are deleted.',
            'Your listings are taken down and their contact details removed.',
          ])
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '•  $line',
                style: TextStyle(color: Colors.grey[400], fontSize: 12, height: 1.4),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey600),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
    );
  }

  InputDecoration _inputDecoration({required String hint, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
      filled: true,
      fillColor: AppColors.surfaceContainer,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      suffixIcon: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.surfaceContainerHigh),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.surfaceContainerHigh),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.grey400),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white, width: 1.5),
      ),
      errorStyle: const TextStyle(color: AppColors.grey300),
    );
  }
}
