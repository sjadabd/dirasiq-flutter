import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dirasiq/core/services/auth_service.dart';
import 'package:dirasiq/features/auth/screens/email_verification_screen.dart';

class AuthController extends GetxController {
  final AuthService _authService = AuthService();

  /// تسجيل الدخول
  Future<void> login(
    BuildContext context,
    String email,
    String password,
  ) async {
    final String? error = await _authService.login(email, password);
    if (error == null) {
      Get.offAllNamed('/home');
    } else if (error.contains('غير مفعل')) {
      Get.offAll(() => EmailVerificationScreen(email: email));
    } else {
      Get.snackbar('خطأ', error, snackPosition: SnackPosition.BOTTOM);
    }
  }

  /// تسجيل طالب جديد
  Future<void> register(BuildContext context, Map<String, dynamic> data) async {
    String? errorMessage = await _authService.registerStudent(data);

    if (errorMessage == null) {
      Get.offAllNamed('/home');
    } else {
      Get.snackbar('خطأ', errorMessage, snackPosition: SnackPosition.BOTTOM);
    }
  }
}
