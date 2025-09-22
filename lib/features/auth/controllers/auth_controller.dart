import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dirasiq/core/services/auth_service.dart';
import 'package:dirasiq/features/home/home_screen.dart';

class AuthController extends GetxController {
  final AuthService _authService = AuthService();

  /// تسجيل الدخول
  Future<void> login(BuildContext context, String email, String password) async {
    bool success = await _authService.login(email, password);
    if (success) {
      Get.offAll(() => const HomeScreen());
    } else {
      Get.snackbar('خطأ', 'فشل تسجيل الدخول', snackPosition: SnackPosition.BOTTOM);
    }
  }

  /// تسجيل طالب جديد
  Future<void> register(BuildContext context, Map<String, dynamic> data) async {
    String? errorMessage = await _authService.registerStudent(data);

    if (errorMessage == null) {
      Get.offAll(() => const HomeScreen());
    } else {
      Get.snackbar('خطأ', errorMessage, snackPosition: SnackPosition.BOTTOM);
    }
  }
}
