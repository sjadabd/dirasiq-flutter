import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../widgets/auth_text_field.dart';
import '../../../core/services/auth_service.dart';
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
      Get.snackbar('تنبيه', 'يرجى ملء جميع الحقول', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (pass != confirm) {
      Get.snackbar('تنبيه', 'كلمتا المرور غير متطابقتين', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (pass.length < 8) {
      Get.snackbar('تنبيه', 'كلمة المرور يجب أن تكون 8 أحرف على الأقل', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() => _loading = true);
    final error = await _authService.resetPassword(email, code, pass);
    setState(() => _loading = false);

    if (error == null) {
      Get.snackbar('تم', 'تم تحديث كلمة المرور بنجاح، يمكنك تسجيل الدخول الآن', snackPosition: SnackPosition.BOTTOM);
      // إعادة التوجيه صراحةً إلى شاشة تسجيل الدخول
      Get.offAll(() => LoginScreen());
    } else {
      Get.snackbar('خطأ', error, snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعادة تعيين كلمة المرور')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('أدخل البريد، الرمز الذي وصلك، وكلمة المرور الجديدة'),
              const SizedBox(height: 16),
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
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('تأكيد إعادة التعيين'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
