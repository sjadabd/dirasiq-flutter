import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../shared/themes/app_colors.dart';
import '../widgets/auth_text_field.dart';
import '../../../core/services/auth_service.dart';
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

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      Get.snackbar(
        'تنبيه',
        'يرجى إدخال البريد الإلكتروني',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withValues(alpha: 0.1),
        colorText: AppColors.error,
      );
      return;
    }

    setState(() => _loading = true);
    final error = await _authService.requestPasswordReset(email);
    setState(() => _loading = false);

    if (error == null) {
      Get.snackbar(
        'تم الإرسال',
        'تم إرسال رمز إعادة التعيين إلى بريدك الإلكتروني',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success.withValues(alpha: 0.1),
        colorText: AppColors.success,
      );
      Get.to(() => ResetPasswordScreen(initialEmail: email));
    } else {
      Get.snackbar(
        'خطأ',
        error,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error.withValues(alpha: 0.1),
        colorText: AppColors.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('استرجاع كلمة المرور'),
        backgroundColor: isDark ? scheme.surface : scheme.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 30),
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: AppColors.gradientMotivation,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_reset_rounded,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'نسيت كلمة المرور؟',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'أدخل بريدك الإلكتروني لإرسال رمز إعادة التعيين',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),

              AuthTextField(
                controller: _emailController,
                label: 'البريد الإلكتروني',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 28),

              Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppColors.gradientMotivation,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'إرسال رمز إعادة التعيين',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () => Get.back(),
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 14,
                  color: scheme.primary,
                ),
                label: Text(
                  'العودة لتسجيل الدخول',
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
