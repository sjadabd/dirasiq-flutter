import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mulhimiq/core/services/auth_service.dart';
import 'package:mulhimiq/shared/themes/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    // استخدام SchedulerBinding لتجنب مشاكل Hot Reload
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          _handleStartup();
        }
      });
    });
  }

  Future<void> _handleStartup() async {
    if (!mounted) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    // استخدام مفتاح جديد كلياً لإجبار عرض التعريف مرة واحدة لكل المستخدمين
    const String onboardingSeenKey = 'has_seen_onboarding_2025_v1';
    final bool hasSeenOnboarding = prefs.getBool(onboardingSeenKey) ?? false;
    final loggedIn = await _authService.isLoggedIn();

    if (loggedIn) {
      final complete = await _authService.isProfileComplete();
      if (!mounted) {
        return;
      }
      if (complete) {
        Navigator.pushReplacementNamed(context, "/home");
      } else {
        Navigator.pushReplacementNamed(context, "/complete-profile");
      }
      return;
    }

    // غير مسجل دخول
    if (!hasSeenOnboarding) {
      // أول مرة: اذهب للتعريف
      if (mounted) {
        try {
          // استخدام Get.offAllNamed بدلاً من Navigator
          Get.offAllNamed('/onboarding');
        } catch (e) {
          Get.snackbar(
            'خطأ',
            'حدث خطأ أثناء التوجيه إلى التوجيه.',
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkBackground
                : AppColors.background,
            colorText: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkTextPrimary
                : AppColors.textPrimary,
            margin: const EdgeInsets.all(12),
            borderRadius: 12,
            icon: const Icon(Icons.error, color: AppColors.error),
            duration: const Duration(seconds: 7),
          );
        }
      } else {}
    } else {
      // فتح سابقًا: فقط إلى تسجيل الدخول
      if (mounted) {
        Get.offAllNamed("/login");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // شعار التطبيق (لوغو)
            SizedBox(
              width: 140,
              height: 140,
              child: Image.asset('assets/logo.png', fit: BoxFit.contain),
            ),
            const SizedBox(height: 24),

            // اسم التطبيق
            Text(
              'Mulhim IQ',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // الشعار
            Text(
              'منصتك التعليمية المتكاملة',
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 40),

            // مؤشر التحميل
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),

            // زر إعادة تعيين للاختبار (فقط في وضع التطوير)
            const SizedBox(height: 20),
            if (const bool.fromEnvironment('dart.vm.product') == false)
              TextButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('has_seen_onboarding_2025_v1');
                  await prefs.remove('has_seen_welcome_dialog');
                  setState(() {});
                },
                child: const Text(
                  'إعادة تعيين الـ Onboarding (للاختبار)',
                  style: TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
