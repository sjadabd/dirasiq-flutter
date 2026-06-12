// Auth → Login (MulhimIQ design-system pass).
//
// Presentation only. The auth flow is UNCHANGED: AuthController.login (which
// uses AuthService + RoleRouter for role-aware redirect), Google sign-in
// (GoogleAuthService + RoleRouter, EMAIL_VERIFICATION_REQUIRED branch), Apple
// sign-in, and navigation to Forgot/Register/EmailVerification/join-as-teacher
// are all preserved. Only a local submitting flag was added for the button's
// loading/disabled state.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:mulhimiq/core/services/apple_auth_service.dart';
import 'package:mulhimiq/core/services/google_auth_service.dart';
import 'package:mulhimiq/core/services/role_router.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_text_field.dart';
import 'email_verification_screen.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthController _controller = Get.find<AuthController>();
  final AppleAuthService _appleAuthService = AppleAuthService();

  bool _submitting = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await _controller.login(context, _emailController.text.trim(), _passwordController.text.trim());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handleGoogleLogin(BuildContext context) async {
    debugPrint('[LoginScreen] Google login button pressed');
    final googleAuth = GoogleAuthService();
    final start = DateTime.now();
    final String? error = await googleAuth.signInWithGoogle("student");
    debugPrint(
      '[LoginScreen] signInWithGoogle finished in ${DateTime.now().difference(start).inMilliseconds}ms error=${error != null}',
    );

    if (!context.mounted) return;

    if (error == null) {
      debugPrint('[LoginScreen] Google sign-in success — dispatching via RoleRouter');
      await RoleRouter.routeAfterAuth();
    } else if (error == "EMAIL_VERIFICATION_REQUIRED") {
      final email = GoogleAuthService().lastEmail ?? '';
      debugPrint('[LoginScreen] account not activated -> navigate EmailVerificationScreen for $email');
      Get.offAll(() => EmailVerificationScreen(email: email));
    } else {
      debugPrint('[LoginScreen] Google sign-in error: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _handleAppleLogin(BuildContext context) async {
    final String? error = await _appleAuthService.signInWithApple("student");
    if (!context.mounted) return;
    if (error == null) {
      await RoleRouter.routeAfterAuth();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dsTheme = isDark ? MqTheme.dark() : MqTheme.light();
    final bool isApple =
        defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;

    return Theme(
      data: dsTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) {
            final m = context.mq;
            return Scaffold(
              backgroundColor: m.page,
              body: SafeArea(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.xl, MqSpacing.lg, MqSpacing.lg),
                  child: Column(
                    children: [
                      _brand(context),
                      MqSpacing.gapXl,
                      MqCard(
                        padding: const EdgeInsets.all(MqSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('مرحباً بك من جديد 👋', style: context.text.titleLarge),
                            const SizedBox(height: 4),
                            Text('سجّل دخولك للمتابعة إلى حسابك', style: context.text.bodySmall),
                            MqSpacing.gapLg,
                            AuthTextField(
                              controller: _emailController,
                              label: 'البريد الإلكتروني',
                              keyboardType: TextInputType.emailAddress,
                              prefixIcon: Icons.alternate_email_rounded,
                            ),
                            MqSpacing.gapMd,
                            AuthTextField(
                              controller: _passwordController,
                              label: 'كلمة المرور',
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              prefixIcon: Icons.lock_outline_rounded,
                              suffixIcon: IconButton(
                                icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    size: 20, color: m.ink3),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: MqButton.text(
                                label: 'نسيت كلمة المرور؟',
                                size: MqButtonSize.small,
                                onPressed: () => Get.to(() => const ForgotPasswordScreen()),
                              ),
                            ),
                            MqSpacing.gapXs,
                            MqButton(label: 'تسجيل الدخول', icon: Icons.login_rounded, loading: _submitting, onPressed: _login),
                            MqSpacing.gapMd,
                            _dividerOr(context),
                            MqSpacing.gapMd,
                            _googleButton(context),
                            if (isApple) ...[
                              MqSpacing.gapSm,
                              SizedBox(
                                width: double.infinity,
                                height: MqSize.buttonHeight,
                                child: SignInWithAppleButton(
                                  onPressed: () => _handleAppleLogin(context),
                                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                                  text: 'تسجيل الدخول Apple',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      MqSpacing.gapLg,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('ليس لديك حساب؟', style: context.text.bodySmall),
                          MqButton.text(label: 'إنشاء حساب جديد', size: MqButtonSize.small, onPressed: () => Get.to(() => const RegisterScreen())),
                        ],
                      ),
                      MqSpacing.gapXs,
                      MqButton.secondary(
                        label: 'انضم كأستاذ (تقديم طلب)',
                        icon: Icons.school_outlined,
                        onPressed: () => Get.toNamed('/join-as-teacher'),
                      ),
                      MqSpacing.gapLg,
                      Text('© ملهم — جميع الحقوق محفوظة', style: context.text.labelSmall),
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

  Widget _brand(BuildContext context) {
    final m = context.mq;
    return Column(
      children: [
        Container(
          width: 76, height: 76,
          decoration: BoxDecoration(color: m.accentSoft, borderRadius: MqRadius.brXl),
          child: Icon(Icons.school_rounded, color: m.accent, size: 40),
        ),
        MqSpacing.gapSm,
        Text('ملهم IQ', style: context.text.headlineSmall?.copyWith(color: m.accent, fontWeight: FontWeight.w800)),
        Text('منصة التعليم الذكية', style: context.text.bodySmall),
      ],
    );
  }

  Widget _dividerOr(BuildContext context) {
    final m = context.mq;
    return Row(children: [
      Expanded(child: Divider(color: m.line)),
      Padding(padding: const EdgeInsets.symmetric(horizontal: MqSpacing.sm), child: Text('أو', style: context.text.labelSmall)),
      Expanded(child: Divider(color: m.line)),
    ]);
  }

  Widget _googleButton(BuildContext context) {
    final m = context.mq;
    return SizedBox(
      width: double.infinity,
      height: MqSize.buttonHeight,
      child: OutlinedButton.icon(
        onPressed: () => _handleGoogleLogin(context),
        icon: Image.asset('assets/google_logo.png', height: 20, width: 20),
        label: Text('المتابعة باستخدام Google', style: context.text.labelLarge),
        style: OutlinedButton.styleFrom(
          foregroundColor: m.ink,
          side: BorderSide(color: m.line),
          shape: RoundedRectangleBorder(borderRadius: MqRadius.brMd),
        ),
      ),
    );
  }
}
