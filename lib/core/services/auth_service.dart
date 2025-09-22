import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();

  /// ✅ تسجيل طالب جديد
  Future<String?> registerStudent(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.dio.post(
        "/auth/register/student",
        data: data,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();

        if (response.data["token"] != null) {
          await prefs.setString("token", response.data["token"]);
        }
        if (response.data["user"] != null) {
          await prefs.setString("user", jsonEncode(response.data["user"]));
        }

        return null; // ✅ نجاح
      }

      return response.data["message"] ?? "فشل التسجيل";
    } on DioException catch (e) {
      return e.response?.data?["message"] ?? "خطأ في السيرفر";
    }
  }

  /// ✅ تسجيل الدخول
  Future<bool> login(String email, String password) async {
    try {
      final response = await _apiService.dio.post(
        "/auth/login",
        data: {"email": email, "password": password},
      );

      if (response.statusCode == 200 && response.data["success"] == true) {
        final prefs = await SharedPreferences.getInstance();

        // 🟢 حفظ التوكن
        if (response.data["token"] != null) {
          await prefs.setString("token", response.data["token"]);
        }

        // 🟢 حفظ بيانات المستخدم
        if (response.data["data"]?["user"] != null) {
          await prefs.setString(
              "user", jsonEncode(response.data["data"]["user"]));
        }

        return true;
      }

      return false;
    } on DioException catch (e) {
      print("❌ Login error: ${e.response?.data ?? e.message}");
      return false;
    }
  }

  /// ✅ إعادة إرسال رمز التحقق
  Future<String?> resendVerification(String email) async {
    try {
      final response = await _apiService.dio.post(
        "/auth/resend-verification",
        data: {"email": email},
      );

      if (response.statusCode == 200) return null;

      return response.data["message"] ?? "فشل إعادة الإرسال";
    } on DioException catch (e) {
      return e.response?.data?["message"] ?? "خطأ في السيرفر";
    }
  }

  /// ✅ التحقق من البريد
  Future<String?> verifyEmail(String email, String token) async {
    try {
      final response = await _apiService.dio.post(
        "/auth/verify-email",
        data: {"email": email, "verificationToken": token},
      );

      if (response.statusCode == 200) return null;

      return response.data["message"] ?? "فشل التحقق";
    } on DioException catch (e) {
      return e.response?.data?["message"] ?? "خطأ في السيرفر";
    }
  }

  /// ✅ هل المستخدم مسجل دخول؟
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("token") != null;
  }

  /// ✅ تسجيل خروج
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("token");
    await prefs.remove("user");
  }

  /// ✅ جلب بيانات المستخدم من التخزين
  Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString("user");

    if (userStr != null) {
      return jsonDecode(userStr);
    }

    return null;
  }

  /// ✅ التحقق من اكتمال البروفايل
  Future<bool> isProfileComplete() async {
    final user = await getUser();
    if (user == null) return false;

    // 🟡 تحقق من الحقول الإلزامية
    if ((user["studentPhone"] == null ||
        user["studentPhone"].toString().isEmpty) ||
        (user["gender"] == null || user["gender"].toString().isEmpty) ||
        (user["birthDate"] == null)) {
      return false;
    }

    return true;
  }

  /// ✅ إكمال بيانات الملف الشخصي
  Future<Map<String, dynamic>> completeProfile(
      Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");

      final response = await _apiService.dio.post(
        "/auth/complete-profile",
        data: data,
        options: Options(
          headers: {"Authorization": "Bearer $token"},
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // 🟢 تخزين بيانات المستخدم بعد التحديث
        if (response.data["data"]?["user"] != null) {
          await prefs.setString(
              "user", jsonEncode(response.data["data"]["user"]));
        }

        return {"success": true, "data": response.data["data"]};
      }

      return {
        "success": false,
        "message": response.data["message"] ?? "فشل حفظ البيانات",
      };
    } on DioException catch (e) {
      return {
        "success": false,
        "message": e.response?.data?["message"] ?? "خطأ في السيرفر",
      };
    }
  }
}
