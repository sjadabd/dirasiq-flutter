// Auth → Email / OTP verification (MulhimIQ design-system pass).
//
// Presentation only. The verify (AuthService.verifyEmail → LoginScreen) and
// resend (AuthService.resendVerification) flows are UNCHANGED; a local resend
// cooldown timer + submitting flag were added for UX (no API change).

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mulhimiq/core/services/auth_service.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';
import 'login_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _codeController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _loading = false;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown(); // a code was just sent before reaching this screen
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startCooldown([int seconds = 60]) {
    _timer?.cancel();
    setState(() => _cooldown = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _snack('أدخل رمز التحقق');
      return;
    }
    setState(() => _loading = true);
    final error = await _authService.verifyEmail(widget.email, code);
    if (!mounted) return;
    setState(() => _loading = false);
    if (error == null) {
      _snack('تم التحقق بنجاح');
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    } else {
      _snack(error);
    }
  }

  Future<void> _resend() async {
    if (_cooldown > 0 || _loading) return;
    setState(() => _loading = true);
    final error = await _authService.resendVerification(widget.email);
    if (!mounted) return;
    setState(() => _loading = false);
    if (error == null) {
      _snack('تم إرسال رمز جديد إلى بريدك الإلكتروني');
      _startCooldown();
    } else {
      _snack(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dsTheme = isDark ? MqTheme.dark() : MqTheme.light();
    return Theme(
      data: dsTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) {
            final m = context.mq;
            return Scaffold(
              backgroundColor: m.page,
              appBar: AppBar(title: const Text('التحقق من البريد الإلكتروني')),
              body: SafeArea(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(MqSpacing.lg),
                  child: Column(
                    children: [
                      MqSpacing.gapXl,
                      Container(
                        width: 84, height: 84,
                        decoration: BoxDecoration(color: m.accentSoft, shape: BoxShape.circle),
                        child: Icon(Icons.mark_email_unread_rounded, color: m.accent, size: 42),
                      ),
                      MqSpacing.gapLg,
                      Text('تحقّق من بريدك الإلكتروني', style: context.text.titleLarge, textAlign: TextAlign.center),
                      MqSpacing.gapXs,
                      Text('أرسلنا رمز تحقّق إلى', textAlign: TextAlign.center, style: context.text.bodySmall),
                      Text(widget.email,
                          textAlign: TextAlign.center,
                          style: context.text.bodyMedium?.copyWith(color: m.accent, fontWeight: FontWeight.w700)),
                      MqSpacing.gapLg,
                      MqCard(
                        padding: const EdgeInsets.all(MqSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _codeController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: MqTypography.mono(color: m.ink, size: 22, weight: FontWeight.w700)
                                  .copyWith(letterSpacing: 8),
                              decoration: InputDecoration(
                                hintText: '— — — — — —',
                                hintStyle: context.text.titleMedium?.copyWith(color: m.ink3, letterSpacing: 6),
                                filled: true,
                                fillColor: m.fill,
                                contentPadding: const EdgeInsets.symmetric(vertical: MqSpacing.md),
                                border: OutlineInputBorder(borderRadius: MqRadius.brMd, borderSide: BorderSide(color: m.line)),
                                enabledBorder: OutlineInputBorder(borderRadius: MqRadius.brMd, borderSide: BorderSide(color: m.line)),
                                focusedBorder: OutlineInputBorder(borderRadius: MqRadius.brMd, borderSide: BorderSide(color: m.accent, width: 1.6)),
                              ),
                            ),
                            MqSpacing.gapMd,
                            MqButton(label: 'تأكيد الرمز', icon: Icons.verified_rounded, loading: _loading, onPressed: _verify),
                            MqSpacing.gapXs,
                            Center(
                              child: _cooldown > 0
                                  ? Text('إعادة الإرسال خلال $_cooldown ث', style: context.text.labelSmall)
                                  : MqButton.text(label: 'إعادة إرسال الرمز', icon: Icons.refresh_rounded,
                                      onPressed: _loading ? null : _resend),
                            ),
                          ],
                        ),
                      ),
                      MqSpacing.gapMd,
                      Text('تأكّد من فحص مجلد البريد غير الهام (Spam)', textAlign: TextAlign.center, style: context.text.labelSmall),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
