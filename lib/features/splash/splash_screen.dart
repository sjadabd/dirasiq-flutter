import 'package:flutter/material.dart';
import 'package:dirasiq/core/services/auth_service.dart';

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
    _checkLogin();
  }

  void _checkLogin() async {
    final loggedIn = await _authService.isLoggedIn();
    await Future.delayed(const Duration(seconds: 2)); // شاشة تحميل مؤقتة
    if (!mounted) return;

    if (loggedIn) {
      final complete = await _authService.isProfileComplete();

      if (complete) {
        // ✅ بيانات مكتملة → يروح على الرئيسية
        Navigator.pushReplacementNamed(context, "/home");
      } else {
        // ⚠️ بيانات ناقصة → يروح على شاشة الإكمال
        Navigator.pushReplacementNamed(context, "/complete-profile");
      }
    } else {
      // ⛔ غير مسجل دخول → يروح على تسجيل الدخول
      Navigator.pushReplacementNamed(context, "/login");
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
