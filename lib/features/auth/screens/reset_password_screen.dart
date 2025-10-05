import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../widgets/auth_text_field.dart';
import '../../../core/services/auth_service.dart';
import 'login_screen.dart';
import '../../../shared/themes/app_colors.dart';
import '../widgets/auth_button.dart';

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
    if (widget.initialEmail != null) {
      _emailController.text = widget.initialEmail!;
    }
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final pass = _newPassController.text;
    final confirm = _confirmPassController.text;

    if (email.isEmpty || code.isEmpty || pass.isEmpty || confirm.isEmpty) {
      Get.snackbar(
        'تنبيه',
        'يرجى ملء جميع الحقول',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (pass != confirm) {
      Get.snackbar(
        'تنبيه',
        'كلمتا المرور غير متطابقتين',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (pass.length < 8) {
      Get.snackbar(
        'تنبيه',
        'كلمة المرور يجب أن تكون 8 أحرف على الأقل',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _loading = true);
    final error = await _authService.resetPassword(email, code, pass);
    setState(() => _loading = false);

    if (error == null) {
      Get.snackbar(
        'تم',
        'تم تحديث كلمة المرور بنجاح، يمكنك تسجيل الدخول الآن',
        snackPosition: SnackPosition.BOTTOM,
      );
      Get.offAll(() => LoginScreen());
    } else {
      Get.snackbar('خطأ', error, snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('إعادة تعيين كلمة المرور'),
        backgroundColor: scheme.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: 32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),

              // 🧭 أيقونة العنوان
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppColors.gradientWelcome,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_reset_rounded,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              // 🩵 عنوان
              Text(
                "استعادة الوصول إلى حسابك",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                "أدخل البريد الإلكتروني، الرمز المرسل، ثم كلمة المرور الجديدة.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),

              const SizedBox(height: 28),

              // 🧾 الحقول
              AuthTextField(
                controller: _emailController,
                label: 'البريد الإلكتروني',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              AuthTextField(
                controller: _codeController,
                label: 'رمز إعادة التعيين',
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              AuthTextField(
                controller: _newPassController,
                label: 'كلمة المرور الجديدة',
                obscureText: true,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              AuthTextField(
                controller: _confirmPassController,
                label: 'تأكيد كلمة المرور',
                obscureText: true,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 24),

              // 🔘 زر التأكيد
              _loading
                  ? const CircularProgressIndicator()
                  : AuthButton(text: "تأكيد إعادة التعيين", onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}
