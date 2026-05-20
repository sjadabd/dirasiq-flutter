import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mulhimiq/core/services/auth_service.dart';
import 'package:mulhimiq/core/services/role_router.dart';
import 'package:mulhimiq/features/auth/screens/email_verification_screen.dart';

class AuthController extends GetxController {
  final AuthService _authService = AuthService();

  /// تسجيل الدخول — يقبل الطلاب والمعلمين. RoleRouter يقرأ userType من
  /// الـ user المخزّن محلياً ويوجّه إلى /home أو /teacher/home.
  Future<void> login(
    BuildContext context,
    String email,
    String password,
  ) async {
    final String? error = await _authService.login(email, password);
    if (error == null) {
      await RoleRouter.routeAfterAuth();
    } else if (error.contains('غير مفعل')) {
      Get.offAll(() => EmailVerificationScreen(email: email));
    } else {
      Get.snackbar('خطأ', error, snackPosition: SnackPosition.BOTTOM);
    }
  }

  /// تسجيل طالب جديد. الـ register path الخاصة بالمعلمين تتم من لوحة التحكم
  /// (Phase 0 bootstrap) فلا حاجة لشاشة تسجيل معلم في الموبايل.
  Future<void> register(BuildContext context, Map<String, dynamic> data) async {
    String? errorMessage = await _authService.registerStudent(data);

    if (errorMessage == null) {
      await RoleRouter.routeAfterAuth();
    } else {
      Get.snackbar('خطأ', errorMessage, snackPosition: SnackPosition.BOTTOM);
    }
  }
}
