import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_text_field.dart';
import 'register_screen.dart';
import '../../../core/services/google_auth_service.dart';
import '../../../core/services/auth_service.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:dirasiq/core/services/apple_auth_service.dart';
import '../../profile/complete_profile_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatelessWidget {
  LoginScreen({super.key});

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthController _controller = Get.find<AuthController>();
  final AuthService _authService = AuthService();
  final AppleAuthService _appleAuthService = AppleAuthService();

  Future<void> _handleGoogleLogin(BuildContext context) async {
    debugPrint('[LoginScreen] Google login button pressed');
    final googleAuth = GoogleAuthService();
    final start = DateTime.now();
    final String? error = await googleAuth.signInWithGoogle("student");
    debugPrint('[LoginScreen] signInWithGoogle finished in ${DateTime.now().difference(start).inMilliseconds}ms error=${error != null}');

    if (!context.mounted) return;

    if (error == null) {
      debugPrint('[LoginScreen] Google sign-in success, checking profile completeness');
      final complete = await _authService.isProfileComplete();

      if (complete) {
        debugPrint('[LoginScreen] profile complete -> navigate /home');
        Get.offAllNamed('/home');
      } else {
        debugPrint('[LoginScreen] profile incomplete -> navigate CompleteProfileScreen');
        Get.offAll(() => const CompleteProfileScreen());
      }
    } else {
      debugPrint('[LoginScreen] Google sign-in error: $error');
      Get.snackbar('خطأ', error, snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _handleAppleLogin(BuildContext context) async {
    final String? error = await _appleAuthService.signInWithApple("student");

    if (!context.mounted) return;

    if (error == null) {
      final complete = await _authService.isProfileComplete();

      if (complete) {
        Get.offAllNamed('/home');
      } else {
        Get.offAll(() => const CompleteProfileScreen());
      }
    } else {
      Get.snackbar('خطأ', error, snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bool isApple =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 🔹 Header
              const SizedBox(height: 40),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  color: scheme.primary,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "مرحباً بك من جديد 👋",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "سجل دخولك للمتابعة إلى حسابك",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 40),

              // 🔹 Input Fields
              Column(
                children: [
                  AuthTextField(
                    controller: _emailController,
                    label: "البريد الإلكتروني",
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  AuthTextField(
                    controller: _passwordController,
                    label: "كلمة المرور",
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 🔹 Login Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    await _controller.login(
                      context,
                      _emailController.text.trim(),
                      _passwordController.text.trim(),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "تسجيل الدخول",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 🔹 Divider
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: scheme.outline.withOpacity(0.4),
                      thickness: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      "أو",
                      style: TextStyle(
                        color: scheme.onSurface.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: scheme.outline.withOpacity(0.4),
                      thickness: 1,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 🔹 Google Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => _handleGoogleLogin(context),
                  icon: Image.asset(
                    "assets/google_logo.png",
                    height: 20,
                    width: 20,
                  ),
                  label: const Text(
                    "تسجيل الدخول باستخدام Google",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: scheme.outline.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    foregroundColor: scheme.onSurface,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              if (isApple) ...[
                // 🔹 Apple Sign-In Button (iOS/macOS only)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: SignInWithAppleButton(
                    onPressed: () => _handleAppleLogin(context),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    text: 'تسجيل الدخول Apple',
                  ),
                ),

                const SizedBox(height: 20),
              ],

              // 🔹 Forgot Password / Register
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Get.to(() => const ForgotPasswordScreen()),
                    child: Text(
                      "نسيت كلمة المرور؟",
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Get.to(() => RegisterScreen()),
                    child: Text(
                      "إنشاء حساب جديد",
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // 🔹 Small Footer
              Text(
                "© ملهم - جميع الحقوق محفوظة",
                style: TextStyle(
                  color: scheme.onSurface.withOpacity(0.4),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
