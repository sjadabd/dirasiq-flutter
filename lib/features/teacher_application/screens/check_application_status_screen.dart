// Phase 8.12 — public "where is my teacher application?" screen.
// (Teacher Design System pass — logic unchanged.)
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
import 'package:get/get.dart';

import 'package:mulhimiq/core/services/teacher_application_api_service.dart';

import '../../teacher/shared/design/teacher_design.dart';
import '../widgets/join_widgets.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: isDark ? MqTheme.dark() : MqTheme.light(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(builder: (context) {
          final mq = context.mq;
          return Scaffold(
            backgroundColor: mq.page,
            appBar: const JoinAppBar(title: 'حالة طلب الانضمام'),
            body: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    MqSpacing.xl, MqSpacing.lg, MqSpacing.xl, MqSpacing.xl),
                child: switch (_stage) {
                  _Stage.enterEmail => _buildEmailStage(context),
                  _Stage.enterCode => _buildCodeStage(context),
                  _Stage.showStatus => _buildStatusStage(context),
                },
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmailStage(BuildContext context) {
    final mq = context.mq;
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const JoinHeroIcon(icon: Icons.search, size: 88),
          const SizedBox(height: MqSpacing.xl),
          Text('تحقّق من حالة طلبك',
              textAlign: TextAlign.center, style: context.text.headlineSmall),
          const SizedBox(height: MqSpacing.sm),
          Text(
            'أدخل البريد الإلكتروني الذي استخدمته عند التقديم وسنرسل إليك رمزاً للاطلاع على الحالة.',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: mq.ink2),
          ),
          const SizedBox(height: MqSpacing.xl),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _requestOtp(),
            decoration: const InputDecoration(
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
          const SizedBox(height: MqSpacing.lg),
          MqButton(
            label: _busy ? 'جارٍ الإرسال…' : 'إرسال الرمز',
            icon: _busy ? null : Icons.send_outlined,
            loading: _busy,
            onPressed: _busy ? null : _requestOtp,
          ),
          if (_error != null) ...[
            const SizedBox(height: MqSpacing.md),
            JoinErrorBox(message: _error!),
          ],
        ],
      ),
    );
  }

  Widget _buildCodeStage(BuildContext context) {
    return Form(
      key: _codeFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const JoinHeroIcon(icon: Icons.mark_email_read_outlined, size: 88),
          const SizedBox(height: MqSpacing.xl),
          Text('أدخل الرمز',
              textAlign: TextAlign.center, style: context.text.headlineSmall),
          const SizedBox(height: MqSpacing.md),
          if (_info != null) JoinInfoBox(message: _info!),
          const SizedBox(height: MqSpacing.lg),
          JoinOtpField(
            controller: _codeCtrl,
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.length != 6) return 'الرمز يجب أن يكون 6 أرقام.';
              return null;
            },
          ),
          const SizedBox(height: MqSpacing.lg),
          MqButton(
            label: _busy ? 'جارٍ التحقق…' : 'تأكيد',
            icon: _busy ? null : Icons.verified_outlined,
            loading: _busy,
            onPressed: _busy ? null : _verifyOtp,
          ),
          const SizedBox(height: MqSpacing.sm),
          MqButton.text(
            label: 'استخدام بريد إلكتروني آخر',
            expand: true,
            onPressed: _busy ? null : _resetToEmail,
          ),
          if (_error != null) ...[
            const SizedBox(height: MqSpacing.md),
            JoinErrorBox(message: _error!),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusStage(BuildContext context) {
    final result = _result;
    if (result == null) return _buildEmailStage(context);

    final v = _statusVisuals(context, result.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JoinHeroIcon(icon: v.icon, tone: v.accent, size: 96),
        const SizedBox(height: MqSpacing.xl),
        Text(v.title,
            textAlign: TextAlign.center, style: context.text.headlineSmall),
        const SizedBox(height: MqSpacing.md),
        Text(
          v.subtitle,
          textAlign: TextAlign.center,
          style: context.text.bodyMedium?.copyWith(color: context.mq.ink2),
        ),
        if (result.status == 'rejected' &&
            (result.rejectionReason?.isNotEmpty ?? false)) ...[
          const SizedBox(height: MqSpacing.xl),
          _quoteBox(context, 'سبب الرفض', result.rejectionReason!, v.accent),
        ],
        if (result.status == 'needs_more_info' &&
            (result.adminNotes?.isNotEmpty ?? false)) ...[
          const SizedBox(height: MqSpacing.xl),
          _quoteBox(context, 'ملاحظات الإدارة', result.adminNotes!, v.accent),
        ],
        const SizedBox(height: MqSpacing.xl),
        if (result.status == 'rejected' || result.status == 'needs_more_info')
          Padding(
            padding: const EdgeInsets.only(bottom: MqSpacing.sm),
            child: MqButton(
              label: 'تقديم طلب جديد',
              icon: Icons.refresh,
              onPressed: () =>
                  Get.off(() => const TeacherApplicationFormScreen()),
            ),
          ),
        MqButton.secondary(
          label: 'استعلام عن طلب آخر',
          onPressed: _resetToEmail,
        ),
      ],
    );
  }

  Widget _quoteBox(
      BuildContext context, String title, String body, Color accent) {
    return Container(
      padding: const EdgeInsets.all(MqSpacing.lg),
      decoration: BoxDecoration(
        border: Border.all(color: accent.withValues(alpha: 0.4)),
        borderRadius: MqRadius.brMd,
        color: accent.withValues(alpha: 0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: context.text.labelMedium
                  ?.copyWith(color: accent, fontWeight: FontWeight.w700)),
          const SizedBox(height: MqSpacing.xs),
          Text(body,
              style: context.text.bodyMedium
                  ?.copyWith(color: context.mq.ink, height: 1.5)),
        ],
      ),
    );
  }

  _StatusVisuals _statusVisuals(BuildContext context, String status) {
    final t = context.teacher;
    switch (status) {
      case 'approved':
        return _StatusVisuals(
          icon: Icons.check_circle_outline,
          title: 'تمّت الموافقة',
          subtitle:
              'تمت الموافقة على طلبك. يمكنك تسجيل الدخول الآن باستخدام بياناتك.',
          accent: t.success,
        );
      case 'rejected':
        return _StatusVisuals(
          icon: Icons.cancel_outlined,
          title: 'تم رفض الطلب',
          subtitle: 'نأسف لإبلاغك بأنه لم تتم الموافقة على طلبك في هذه المرة.',
          accent: t.danger,
        );
      case 'needs_more_info':
        return _StatusVisuals(
          icon: Icons.help_outline,
          title: 'مطلوب معلومات إضافية',
          subtitle:
              'يحتاج فريق المراجعة إلى معلومات إضافية لإكمال دراسة طلبك.',
          accent: t.warning,
        );
      case 'pending':
      default:
        return _StatusVisuals(
          icon: Icons.hourglass_top_outlined,
          title: 'الطلب قيد المراجعة',
          subtitle:
              'تم استلام طلبك وهو قيد المراجعة من قبل فريق الإدارة. سنتواصل معك قريباً.',
          accent: t.info,
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
