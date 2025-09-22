import 'dart:io';
import 'package:dio/dio.dart';

class ApiService {
  final Dio _dio;

  static String getBaseUrl() {
    // ✅ بدل الـ IP بعنوان السيرفر عند النشر
    const String baseUrl = "http://192.168.68.103:3000/api";

    if (Platform.isAndroid) {
      return baseUrl; // عند تشغيل التطبيق على Android Emulator أو جهاز
    } else if (Platform.isIOS) {
      return baseUrl; // نفس الشيء لـ iOS
    } else {
      return baseUrl; // للويب أو الديسكتوب
    }
  }

  ApiService()
      : _dio = Dio(
    BaseOptions(
      baseUrl: getBaseUrl(),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
    ),
  ) {
    // ✅ إضافة Interceptor لطباعة الطلبات والردود (للتصحيح)
    _dio.interceptors.add(LogInterceptor(
      request: true,
      requestBody: true,
      responseBody: true,
      error: true,
    ));
  }

  Dio get dio => _dio;

  /// ✅ جلب الصفوف (للطلاب)
  Future<List<Map<String, dynamic>>> fetchGrades() async {
    try {
      final response = await _dio.get("/grades/all-student");

      if (response.statusCode == 200 && response.data["success"] == true) {
        return List<Map<String, dynamic>>.from(response.data["data"]);
      } else {
        throw Exception(response.data["message"] ?? "فشل تحميل الصفوف");
      }
    } catch (e) {
      throw Exception("❌ خطأ أثناء تحميل الصفوف: $e");
    }
  }

  /// ✅ مثال: جلب الصفوف للمعلمين (لو عندك API مختلف)
  Future<List<Map<String, dynamic>>> fetchTeacherGrades() async {
    try {
      final response = await _dio.get("/grades/all-teacher");

      if (response.statusCode == 200 && response.data["success"] == true) {
        return List<Map<String, dynamic>>.from(response.data["data"]);
      } else {
        throw Exception(response.data["message"] ?? "فشل تحميل صفوف المعلم");
      }
    } catch (e) {
      throw Exception("❌ خطأ أثناء تحميل صفوف المعلم: $e");
    }
  }
}
