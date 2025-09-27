import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_text_field.dart';
import 'register_screen.dart';
import '../../../core/services/google_auth_service.dart';
import '../../../core/services/auth_service.dart';
import '../../profile/complete_profile_screen.dart';
import 'forgot_password_screen.dart';
import '../../../shared/themes/app_colors.dart';

class LoginScreen extends StatelessWidget {
  LoginScreen({super.key});

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthController _controller = Get.find<AuthController>();
  final AuthService _authService = AuthService();

  Future<void> _handleGoogleLogin(BuildContext context) async {
    final googleAuth = GoogleAuthService();
    final String? error = await googleAuth.signInWithGoogle("student");

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
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Container(
          height: screenHeight,
          child: Column(
            children: [
              // Compact header
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: isSmallScreen ? 16 : 24,
                ),
                child: Row(
                  children: [
                    Container(
                      width: isSmallScreen ? 50 : 60,
                      height: isSmallScreen ? 50 : 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: AppColors.gradientWelcome,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        Icons.login_rounded,
                        color: AppColors.white,
                        size: isSmallScreen ? 24 : 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "مرحباً بك",
                            style: TextStyle(
                              fontSize: isSmallScreen ? 20 : 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            "سجل دخولك للمتابعة",
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Main content - takes remaining space
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Input fields section
                      Column(
                        children: [
                          // Compact email field
                          Container(
                            height: isSmallScreen ? 50 : 56,
                            child: AuthTextField(
                              controller: _emailController,
                              label: "البريد الإلكتروني",
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 12 : 16),

                          // Compact password field
                          Container(
                            height: isSmallScreen ? 50 : 56,
                            child: AuthTextField(
                              controller: _passwordController,
                              label: "كلمة المرور",
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                            ),
                          ),
                        ],
                      ),

                      // Buttons section
                      Column(
                        children: [
                          // Login button
                          Container(
                            height: isSmallScreen ? 48 : 56,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: AppColors.gradientMotivation,
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () async {
                                await _controller.login(
                                  context,
                                  _emailController.text.trim(),
                                  _passwordController.text.trim(),
                                );
                              },
                              child: Text(
                                "تسجيل الدخول",
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 16 : 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.white,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: isSmallScreen ? 8 : 12),

                          // Divider with Google button
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: AppColors.outline,
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text(
                                  "أو",
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: AppColors.outline,
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: isSmallScreen ? 8 : 12),

                          // Google login button
                          Container(
                            height: isSmallScreen ? 48 : 56,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.outline),
                            ),
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.surface,
                                foregroundColor: AppColors.textPrimary,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: Image.asset(
                                "assets/google_logo.png",
                                height: 20,
                                width: 20,
                              ),
                              label: Text(
                                "Google",
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 14 : 16,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              onPressed: () => _handleGoogleLogin(context),
                            ),
                          ),
                        ],
                      ),

                      // Bottom links section
                      Column(
                        children: [
                          // Forgot password and register in one row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () {
                                  Get.to(() => const ForgotPasswordScreen());
                                },
                                child: Text(
                                  "نسيت كلمة المرور؟",
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: isSmallScreen ? 12 : 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Get.to(() => RegisterScreen());
                                },
                                child: Text(
                                  "إنشاء حساب",
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: isSmallScreen ? 12 : 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
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
