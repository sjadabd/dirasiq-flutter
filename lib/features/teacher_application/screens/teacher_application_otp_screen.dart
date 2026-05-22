// Phase 8 — OTP verification step for the email-path teacher application.
//
// Reached AFTER the multi-step form has submitted + files are uploaded for
// applications where authProvider == 'email'. The backend already created
// the row and emailed a 6-digit code; the row is in "pending" state but
// the super-admin alert has NOT fired yet (it waits for verification).
//
// On successful verify the backend fires the onSubmitted hook and the
// applicant lands on the success screen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:mulhimiq/core/services/teacher_application_api_service.dart';

import 'teacher_application_success_screen.dart';

class TeacherApplicationOtpScreen extends StatefulWidget {
  const TeacherApplicationOtpScreen({
    super.key,
    required this.applicationId,
    required this.email,
  });

  final String applicationId;
  final String email;

  @override
  State<TeacherApplicationOtpScreen> createState() =>
      _TeacherApplicationOtpScreenState();
}

class _TeacherApplicationOtpScreenState
    extends State<TeacherApplicationOtpScreen> {
  final _api = TeacherApplicationApiService();
  final _code = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _verifying = false;
  bool _resending = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_verifying) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _verifying = true;
      _error = null;
      _info = null;
    });
    try {
      await _api.verifyEmailOtp(
        applicationId: widget.applicationId,
        code: _code.text.trim(),
      );
      if (!mounted) return;
      Get.off(() => TeacherApplicationSuccessScreen(email: widget.email));
    } on TeacherApplicationApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'حدث خطأ غير متوقع: $e');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_resending) return;
    setState(() {
      _resending = true;
      _error = null;
      _info = null;
    });
    try {
      await _api.resendVerificationCode(applicationId: widget.applicationId);
      if (!mounted) return;
      setState(() => _info = 'تم إرسال رمز جديد إلى ${widget.email}.');
    } on TeacherApplicationApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'تعذر إرسال رمز جديد: $e');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('تحقق من البريد الإلكتروني'),
        backgroundColor: scheme.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.mark_email_read_outlined,
                        size: 44, color: scheme.primary),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'أدخل رمز التحقق',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'أرسلنا رمزاً مكوّناً من 6 أرقام إلى:\n${widget.email}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.75),
                      ),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  style: const TextStyle(
                      fontSize: 28, letterSpacing: 6, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'رمز التحقق',
                    hintText: '------',
                  ),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.length != 6) return 'الرمز يجب أن يكون 6 أرقام.';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _verifying ? null : _verify,
                    icon: _verifying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : const Icon(Icons.verified_outlined, size: 20),
                    label: Text(_verifying ? 'جارٍ التحقق…' : 'تأكيد'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _resending ? null : _resend,
                  icon: _resending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(_resending ? 'جارٍ الإرسال…' : 'إرسال رمز جديد'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      Icon(Icons.error_outline, color: scheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: TextStyle(color: scheme.onErrorContainer)),
                      ),
                    ]),
                  ),
                ],
                if (_info != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline, color: scheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_info!,
                            style: TextStyle(color: scheme.onSurface)),
                      ),
                    ]),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
