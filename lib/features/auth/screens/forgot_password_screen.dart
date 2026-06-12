// Auth → Forgot password (MulhimIQ design-system pass).
//
// Presentation only. AuthService.requestPasswordReset and navigation to
// ResetPasswordScreen are UNCHANGED.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:mulhimiq/core/services/auth_service.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';
import '../widgets/auth_text_field.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _snack('يرجى إدخال البريد الإلكتروني');
      return;
    }
    setState(() => _loading = true);
    final error = await _authService.requestPasswordReset(email);
    if (!mounted) return;
    setState(() => _loading = false);
    if (error == null) {
      _snack('تم إرسال رمز إعادة التعيين إلى بريدك الإلكتروني');
      Get.to(() => ResetPasswordScreen(initialEmail: email));
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
              appBar: AppBar(title: const Text('استرجاع كلمة المرور')),
              body: SafeArea(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(MqSpacing.lg),
                  child: Column(
                    children: [
                      MqSpacing.gapLg,
                      Container(
                        width: 84, height: 84,
                        decoration: BoxDecoration(color: m.accentSoft, shape: BoxShape.circle),
                        child: Icon(Icons.lock_reset_rounded, color: m.accent, size: 42),
                      ),
                      MqSpacing.gapLg,
                      Text('نسيت كلمة المرور؟', style: context.text.titleLarge, textAlign: TextAlign.center),
                      MqSpacing.gapXs,
                      Text('أدخل بريدك الإلكتروني لإرسال رمز إعادة التعيين',
                          textAlign: TextAlign.center, style: context.text.bodySmall),
                      MqSpacing.gapLg,
                      MqCard(
                        padding: const EdgeInsets.all(MqSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AuthTextField(
                              controller: _emailController,
                              label: 'البريد الإلكتروني',
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.done,
                              prefixIcon: Icons.alternate_email_rounded,
                            ),
                            MqSpacing.gapMd,
                            MqButton(label: 'إرسال رمز إعادة التعيين', icon: Icons.send_rounded, loading: _loading, onPressed: _submit),
                          ],
                        ),
                      ),
                      MqSpacing.gapSm,
                      MqButton.text(label: 'العودة لتسجيل الدخول', icon: Icons.arrow_forward_rounded, onPressed: () => Get.back()),
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
