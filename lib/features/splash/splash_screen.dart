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
    _handleStartup();
  }

  Future<void> _handleStartup() async {
    // مهلة بسيطة لعرض شاشة السبلاتش
    await Future.delayed(const Duration(milliseconds: 800));

    // عرض رسالة ترحيب لأول مرة فقط
    final prefs = await SharedPreferences.getInstance();
    final hasSeenWelcome = prefs.getBool('has_seen_welcome_dialog') ?? false;
    if (!hasSeenWelcome) {
      await _showWelcomeDialog();
      await prefs.setBool('has_seen_welcome_dialog', true);
    }
    if (!mounted) return;

    final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
    final loggedIn = await _authService.isLoggedIn();

    if (loggedIn) {
      // مستخدم قديم مسجل دخول → نُبقي المنطق السابق (الرئيسية/إكمال الملف)
      final complete = await _authService.isProfileComplete();
      if (!mounted) return;
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
      Get.offAllNamed('/onboarding');
    } else {
      // فتح سابقًا: فقط إلى تسجيل الدخول
      Navigator.pushReplacementNamed(context, "/login");
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
            // شعار التطبيق
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.school_rounded,
                size: 60,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),

            // اسم التطبيق
            Text(
              'ديراسِق',
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
          ],
        ),
      ),
    );
  }
}
