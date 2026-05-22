// Phase 8.12 — public "where is my teacher application?" screen.
//
// Three steps, all on one screen:
//   1. Enter email → POST /api/teacher-applications/status/request
//                    (always succeeds; OTP only sent if a row exists)
//   2. Enter OTP   → POST /api/teacher-applications/status/verify
//   3. Display status + reason / admin instructions if applicable
//
// Anti-enumeration: the request step never reveals whether the email
// matches a real application. The verify step rejects "no row" + "wrong
// code" with the same error. Users can re-attempt up to 5 times before
// the OTP is locked and a new one is needed.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:mulhimiq/core/services/teacher_application_api_service.dart';

import 'teacher_application_form_screen.dart';

enum _Stage { enterEmail, enterCode, showStatus }

class CheckApplicationStatusScreen extends StatefulWidget {
  const CheckApplicationStatusScreen({super.key});

  @override
  State<CheckApplicationStatusScreen> createState() =>
      _CheckApplicationStatusScreenState();
}

class _CheckApplicationStatusScreenState
    extends State<CheckApplicationStatusScreen> {
  final _api = TeacherApplicationApiService();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();

  _Stage _stage = _Stage.enterEmail;
  bool _busy = false;
  String? _error;
  String? _info;
  TeacherApplicationStatusResult? _result;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    if (_busy) return;
    if (!(_emailFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await _api.requestStatusOtp(email: _emailCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        _stage = _Stage.enterCode;
        _info =
            'إن كان البريد الإلكتروني مرتبطاً بطلب انضمام، فقد أرسلنا إليه رمز تحقق مكوّن من 6 أرقام.';
      });
    } on TeacherApplicationApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'حدث خطأ غير متوقع: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_busy) return;
    if (!(_codeFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final res = await _api.verifyStatusOtp(
        email: _emailCtrl.text.trim(),
        code: _codeCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _result = res;
        _stage = _Stage.showStatus;
      });
    } on TeacherApplicationApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'حدث خطأ غير متوقع: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _resetToEmail() {
    setState(() {
      _stage = _Stage.enterEmail;
      _codeCtrl.clear();
      _error = null;
      _info = null;
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('حالة طلب الانضمام'),
        backgroundColor: scheme.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: switch (_stage) {
            _Stage.enterEmail => _buildEmailStage(scheme),
            _Stage.enterCode => _buildCodeStage(scheme),
            _Stage.showStatus => _buildStatusStage(scheme),
          },
        ),
      ),
    );
  }

  Widget _buildEmailStage(ColorScheme scheme) {
    return Form(
      key: _emailFormKey,
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
              child: Icon(Icons.search, size: 44, color: scheme.primary),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'تحقّق من حالة طلبك',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'أدخل البريد الإلكتروني الذي استخدمته عند التقديم وسنرسل إليك رمزاً للاطلاع على الحالة.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.75),
                ),
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _requestOtp(),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'البريد الإلكتروني',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) return 'البريد الإلكتروني مطلوب.';
              if (!s.contains('@') || !s.contains('.')) {
                return 'صيغة البريد الإلكتروني غير صحيحة.';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _requestOtp,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Icon(Icons.send_outlined, size: 20),
              label: Text(_busy ? 'جارٍ الإرسال…' : 'إرسال الرمز'),
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (_error != null) _errorBox(scheme, _error!),
        ],
      ),
    );
  }

  Widget _buildCodeStage(ColorScheme scheme) {
    return Form(
      key: _codeFormKey,
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
            'أدخل الرمز',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
          ),
          const SizedBox(height: 8),
          if (_info != null)
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
                  child: Text(_info!, style: TextStyle(color: scheme.onSurface)),
                ),
              ]),
            ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _codeCtrl,
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
              onPressed: _busy ? null : _verifyOtp,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Icon(Icons.verified_outlined, size: 20),
              label: Text(_busy ? 'جارٍ التحقق…' : 'تأكيد'),
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : _resetToEmail,
            child: const Text('استخدام بريد إلكتروني آخر'),
          ),
          if (_error != null) _errorBox(scheme, _error!),
        ],
      ),
    );
  }

  Widget _buildStatusStage(ColorScheme scheme) {
    final result = _result;
    if (result == null) return _buildEmailStage(scheme);

    final config = _statusVisuals(scheme, result.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: config.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(config.icon, size: 48, color: config.accent),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          config.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
        ),
        const SizedBox(height: 12),
        Text(
          config.subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.75),
              ),
        ),
        if (result.status == 'rejected' &&
            (result.rejectionReason?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 24),
          _quoteBox(scheme, 'سبب الرفض', result.rejectionReason!, config.accent),
        ],
        if (result.status == 'needs_more_info' &&
            (result.adminNotes?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 24),
          _quoteBox(scheme, 'ملاحظات الإدارة', result.adminNotes!, config.accent),
        ],
        const SizedBox(height: 28),
        if (result.status == 'rejected' || result.status == 'needs_more_info')
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () =>
                  Get.off(() => const TeacherApplicationFormScreen()),
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('تقديم طلب جديد'),
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        OutlinedButton(
          onPressed: _resetToEmail,
          child: const Text('استعلام عن طلب آخر'),
        ),
      ],
    );
  }

  Widget _errorBox(ColorScheme scheme, String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(Icons.error_outline, color: scheme.error),
          const SizedBox(width: 8),
          Expanded(
            child:
                Text(message, style: TextStyle(color: scheme.onErrorContainer)),
          ),
        ]),
      ),
    );
  }

  Widget _quoteBox(
      ColorScheme scheme, String title, String body, Color accent) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: accent.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
        color: accent.withValues(alpha: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: accent, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(body,
              style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 14,
                  height: 1.5)),
        ],
      ),
    );
  }

  _StatusVisuals _statusVisuals(ColorScheme scheme, String status) {
    switch (status) {
      case 'approved':
        return _StatusVisuals(
          icon: Icons.check_circle_outline,
          title: 'تمّت الموافقة',
          subtitle:
              'تمت الموافقة على طلبك. يمكنك تسجيل الدخول الآن باستخدام بياناتك.',
          accent: const Color(0xFF16A34A),
        );
      case 'rejected':
        return _StatusVisuals(
          icon: Icons.cancel_outlined,
          title: 'تم رفض الطلب',
          subtitle: 'نأسف لإبلاغك بأنه لم تتم الموافقة على طلبك في هذه المرة.',
          accent: scheme.error,
        );
      case 'needs_more_info':
        return _StatusVisuals(
          icon: Icons.help_outline,
          title: 'مطلوب معلومات إضافية',
          subtitle:
              'يحتاج فريق المراجعة إلى معلومات إضافية لإكمال دراسة طلبك.',
          accent: const Color(0xFFD97706),
        );
      case 'pending':
      default:
        return _StatusVisuals(
          icon: Icons.hourglass_top_outlined,
          title: 'الطلب قيد المراجعة',
          subtitle:
              'تم استلام طلبك وهو قيد المراجعة من قبل فريق الإدارة. سنتواصل معك قريباً.',
          accent: scheme.primary,
        );
    }
  }
}

class _StatusVisuals {
  const _StatusVisuals({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
}
