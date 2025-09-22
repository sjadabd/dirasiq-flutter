import 'package:flutter/material.dart';
import '../../home/home_screen.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_button.dart';
import 'register_screen.dart';
import '../../../core/services/google_auth_service.dart';
import '../../../core/services/auth_service.dart';
import '../../profile/complete_profile_screen.dart';

class LoginScreen extends StatelessWidget {
  LoginScreen({super.key});

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthController _controller = Get.find<AuthController>();
  final AuthService _authService = AuthService();

  Future<void> _handleGoogleLogin(BuildContext context) async {
    final googleAuth = GoogleAuthService();
    final success = await googleAuth.signInWithGoogle("student");

    if (!context.mounted) return;

    if (success) {
      final complete = await _authService.isProfileComplete();

      if (complete) {
        Get.offAll(() => const HomeScreen());
      } else {
        Get.offAll(() => const CompleteProfileScreen());
      }
    } else {
      Get.snackbar('خطأ', 'فشل تسجيل الدخول عبر Google ❌', snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تسجيل الدخول")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthTextField(
              controller: _emailController,
              label: "البريد الإلكتروني",
            ),
            const SizedBox(height: 12),
            AuthTextField(
              controller: _passwordController,
              label: "كلمة المرور",
              obscureText: true,
            ),
            const SizedBox(height: 20),
            AuthButton(
              text: "تسجيل الدخول",
              onPressed: () async {
                await _controller.login(
                  context,
                  _emailController.text.trim(),
                  _passwordController.text.trim(),
                );
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Get.to(() => RegisterScreen());
              },
              child: const Text("ليس لديك حساب؟ أنشئ حساب"),
            ),
            const Divider(height: 32, thickness: 1),
            // ✅ زر تسجيل الدخول عبر Google
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 48),
                side: const BorderSide(color: Colors.grey),
                alignment: Alignment.centerLeft,
              ),
              icon: Image.asset(
                "assets/google_logo.png",
                height: 24,
                width: 24,
              ),
              label: const Text(
                "تسجيل الدخول عبر Google",
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: () => _handleGoogleLogin(context),
            ),
          ],
        ),
      ),
    );
  }
}
