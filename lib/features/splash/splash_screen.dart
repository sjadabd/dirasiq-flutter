import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dirasiq/core/services/auth_service.dart';
import 'package:dirasiq/shared/themes/app_colors.dart';
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
      print('❌ Widget unmounted during startup');
      return;
    }

    // تخطي رسالة الترحيب لتجنب مشاكل الـ widget
    final prefs = await SharedPreferences.getInstance();
    print('🔍 Skipping welcome dialog to avoid widget issues');

    final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
    final loggedIn = await _authService.isLoggedIn();
    
    print('🔍 hasSeenOnboarding: $hasSeenOnboarding');
    print('🔍 loggedIn: $loggedIn');

    if (loggedIn) {
      print('👤 User is logged in, checking profile completion...');
      // مستخدم قديم مسجل دخول → نُبقي المنطق السابق (الرئيسية/إكمال الملف)
      final complete = await _authService.isProfileComplete();
      print('🔍 Profile complete: $complete');
      if (!mounted) {
        print('❌ Widget unmounted during profile check');
        return;
      }
      if (complete) {
        print('🏠 Navigating to home...');
        Navigator.pushReplacementNamed(context, "/home");
      } else {
        print('📝 Navigating to complete profile...');
        Navigator.pushReplacementNamed(context, "/complete-profile");
      }
      return;
    }

    // غير مسجل دخول
    if (!hasSeenOnboarding) {
      print('🎯 First time user, navigating to onboarding...');
      // أول مرة: اذهب للتعريف
      if (mounted) {
        try {
          // استخدام Get.offAllNamed بدلاً من Navigator
          Get.offAllNamed('/onboarding');
          print('✅ Successfully navigated to onboarding');
        } catch (e) {
          print('❌ Error navigating to onboarding: $e');
        }
      } else {
        print('❌ Widget already unmounted');
      }
    } else {
      print('🔐 Returning user, navigating to login...');
      // فتح سابقًا: فقط إلى تسجيل الدخول
      if (mounted) {
        Get.offAllNamed("/login");
      }
    }
  }

  Future<void> _showWelcomeDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🔹 أيقونة رئيسية
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.surfaceVariant,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.school_rounded,
                    color: AppColors.primary,
                    size: 46,
                  ),
                ),
                const SizedBox(height: 22),

                // 🔹 العنوان الرئيسي
                Text(
                  'مرحباً بك في ديراسِق 🎓',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),

                // 🔹 النص الوصفي
                Text(
                  'منصة تعليمية حديثة تساعدك على التعلم والتطور والتميز بخطوات واضحة وسهلة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // 🔹 صف الأيقونات
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildFeatureIcon(
                      Icons.auto_stories_rounded,
                      'تعلّم',
                      AppColors.primary,
                    ),
                    _buildFeatureIcon(
                      Icons.trending_up_rounded,
                      'تطور',
                      AppColors.primary,
                    ),
                    _buildFeatureIcon(
                      Icons.workspace_premium_rounded,
                      'تميز',
                      AppColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // 🔹 زر البدء
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'ابدأ الآن',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureIcon(IconData icon, String label, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
      ],
    );
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
                  await prefs.remove('has_seen_onboarding');
                  await prefs.remove('has_seen_welcome_dialog');
                  print('🔄 Reset onboarding state');
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
