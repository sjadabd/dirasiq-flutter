// Auth → Reset password (MulhimIQ design-system pass).
//
// Presentation only. The validation (required fields, password match, min 8
// chars), AuthService.resetPassword, and navigation to LoginScreen are
// UNCHANGED.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:mulhimiq/core/services/auth_service.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';
import '../widgets/auth_text_field.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? initialEmail;
  const ResetPasswordScreen({super.key, this.initialEmail});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null) _emailController.text = widget.initialEmail!;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final pass = _newPassController.text;
    final confirm = _confirmPassController.text;

    if (email.isEmpty || code.isEmpty || pass.isEmpty || confirm.isEmpty) {
      _snack('يرجى ملء جميع الحقول');
      return;
    }
    if (pass != confirm) {
      _snack('كلمتا المرور غير متطابقتين');
      return;
    }
    if (pass.length < 8) {
      _snack('كلمة المرور يجب أن تكون 8 أحرف على الأقل');
      return;
    }

    setState(() => _loading = true);
    final error = await _authService.resetPassword(email, code, pass);
    if (!mounted) return;
    setState(() => _loading = false);
    if (error == null) {
      _snack('تم تحديث كلمة المرور بنجاح، يمكنك تسجيل الدخول الآن');
      Get.offAll(() => const LoginScreen());
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
              appBar: AppBar(title: const Text('إعادة تعيين كلمة المرور')),
              body: SafeArea(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(MqSpacing.lg),
                  child: Column(
                    children: [
                      MqSpacing.gapMd,
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(color: m.accentSoft, shape: BoxShape.circle),
                        child: Icon(Icons.lock_reset_rounded, color: m.accent, size: 40),
                      ),
                      MqSpacing.gapMd,
                      Text('استعادة الوصول إلى حسابك', style: context.text.titleLarge, textAlign: TextAlign.center),
                      MqSpacing.gapXs,
                      Text('أدخل البريد الإلكتروني، الرمز المرسل، ثم كلمة المرور الجديدة.',
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
                              prefixIcon: Icons.alternate_email_rounded,
                            ),
                            MqSpacing.gapMd,
                            AuthTextField(
                              controller: _codeController,
                              label: 'رمز إعادة التعيين',
                              keyboardType: TextInputType.number,
                              prefixIcon: Icons.pin_outlined,
                            ),
                            MqSpacing.gapMd,
                            AuthTextField(
                              controller: _newPassController,
                              label: 'كلمة المرور الجديدة',
                              obscureText: true,
                              prefixIcon: Icons.lock_outline_rounded,
                            ),
                            MqSpacing.gapMd,
                            AuthTextField(
                              controller: _confirmPassController,
                              label: 'تأكيد كلمة المرور',
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              prefixIcon: Icons.lock_outline_rounded,
                            ),
                            MqSpacing.gapMd,
                            MqButton(label: 'تأكيد إعادة التعيين', icon: Icons.check_rounded, loading: _loading, onPressed: _submit),
                          ],
                        ),
                      ),
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
