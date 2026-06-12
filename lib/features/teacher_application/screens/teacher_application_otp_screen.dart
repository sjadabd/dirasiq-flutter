// Phase 8 — OTP verification step for the email-path teacher application.
// (Teacher Design System pass — logic unchanged.)
//
// Reached AFTER the multi-step form has submitted + files are uploaded for
// applications where authProvider == 'email'. The backend already created
// the row and emailed a 6-digit code; the row is in "pending" state but
// the super-admin alert has NOT fired yet (it waits for verification).
//
// On successful verify the backend fires the onSubmitted hook and the
// applicant lands on the success screen.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:mulhimiq/core/services/teacher_application_api_service.dart';

import '../../teacher/shared/design/teacher_design.dart';
import '../widgets/join_widgets.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: isDark ? MqTheme.dark() : MqTheme.light(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(builder: (context) {
          final mq = context.mq;
          return Scaffold(
            backgroundColor: mq.page,
            appBar: const JoinAppBar(title: 'تحقق من البريد الإلكتروني'),
            body: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    MqSpacing.xl, MqSpacing.lg, MqSpacing.xl, MqSpacing.xl),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const JoinHeroIcon(
                          icon: Icons.mark_email_read_outlined, size: 88),
                      const SizedBox(height: MqSpacing.xl),
                      Text('أدخل رمز التحقق',
                          textAlign: TextAlign.center,
                          style: context.text.headlineSmall),
                      const SizedBox(height: MqSpacing.sm),
                      Text(
                        'أرسلنا رمزاً مكوّناً من 6 أرقام إلى:\n${widget.email}',
                        textAlign: TextAlign.center,
                        style:
                            context.text.bodyMedium?.copyWith(color: mq.ink2),
                      ),
                      const SizedBox(height: MqSpacing.xl),
                      JoinOtpField(
                        controller: _code,
                        onSubmitted: (_) => _verify(),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.length != 6) return 'الرمز يجب أن يكون 6 أرقام.';
                          return null;
                        },
                      ),
                      const SizedBox(height: MqSpacing.lg),
                      MqButton(
                        label: _verifying ? 'جارٍ التحقق…' : 'تأكيد',
                        icon: _verifying ? null : Icons.verified_outlined,
                        loading: _verifying,
                        onPressed: _verifying ? null : _verify,
                      ),
                      const SizedBox(height: MqSpacing.sm),
                      MqButton.text(
                        label: _resending ? 'جارٍ الإرسال…' : 'إرسال رمز جديد',
                        icon: _resending ? null : Icons.refresh,
                        loading: _resending,
                        expand: true,
                        onPressed: _resending ? null : _resend,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: MqSpacing.md),
                        JoinErrorBox(message: _error!),
                      ],
                      if (_info != null) ...[
                        const SizedBox(height: MqSpacing.md),
                        JoinInfoBox(message: _info!),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
