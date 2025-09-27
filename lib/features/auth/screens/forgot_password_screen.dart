import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
      Get.snackbar('تنبيه', 'يرجى إدخال البريد الإلكتروني', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    setState(() => _loading = true);
    final error = await _authService.requestPasswordReset(email);
    setState(() => _loading = false);

    if (error == null) {
      Get.snackbar('تم', 'تم إرسال رمز إعادة التعيين إلى بريدك الإلكتروني', snackPosition: SnackPosition.BOTTOM);
      Get.to(() => ResetPasswordScreen(initialEmail: email));
    } else {
      Get.snackbar('خطأ', error, snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استرجاع كلمة المرور')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('أدخل بريدك الإلكتروني لإرسال رمز إعادة التعيين'),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _emailController,
                label: 'البريد الإلكتروني',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('إرسال رمز إعادة التعيين'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
