import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'package:dirasiq/core/services/notification_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();

  /// ✅ تسجيل طالب جديد
  Future<String?> registerStudent(Map<String, dynamic> data) async {
    try {
      // أرسل OneSignal player id مع بيانات التسجيل إن وُجد
      final playerId = await NotificationService.instance.getPlayerId();
      final payload = {
        ...data,
        if (playerId != null && playerId.isNotEmpty)
          'oneSignalPlayerId': playerId,
      };

      final response = await _apiService.dio.post(
        "/auth/register/student",
        data: payload,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();

        if (response.data["token"] != null) {
          await prefs.setString("token", response.data["token"]);
        }
        if (response.data["user"] != null) {
          await prefs.setString("user", jsonEncode(response.data["user"]));
        }

        // إعادة ربط OneSignal باليوزر بعد الحفظ المحلي
        await NotificationService.instance.rebindExternalUserId();
        return null; // ✅ نجاح
      }

      return response.data["message"] ?? "فشل التسجيل";
    } on DioException catch (e) {
      return e.response?.data?["message"] ?? "خطأ في السيرفر";
    }
  }

  /// ✅ تحديث الملف الشخصي
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.dio.post(
        "/auth/update-profile",
        data: data,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        if (response.data["data"]?['user'] != null) {
          await prefs.setString(
            "user",
            jsonEncode(response.data["data"]["user"]),
          );
        }
        return {"success": true, "data": response.data["data"]};
      }

      return {
        "success": false,
        "message": response.data["message"] ?? "فشل تحديث البيانات",
      };
    } on DioException catch (e) {
      return {
        "success": false,
        "message": e.response?.data?["message"] ?? "خطأ في السيرفر",
      };
    }
  }

  /// ✅ طلب إعادة تعيين كلمة المرور
  Future<String?> requestPasswordReset(String email) async {
    try {
      final response = await _apiService.dio.post(
        "/auth/request-password-reset",
        data: {"email": email},
      );

      if (response.statusCode == 200 && (response.data["success"] == true)) {
        return null; // نجاح
      }

      return response.data["message"] ?? "فشل طلب إعادة التعيين";
    } on DioException catch (e) {
      return e.response?.data?["message"] ?? "خطأ في السيرفر";
    }
  }

  /// ✅ تنفيذ إعادة تعيين كلمة المرور
  Future<String?> resetPassword(
    String email,
    String codeOrToken,
    String newPassword,
  ) async {
    try {
      final response = await _apiService.dio.post(
        "/auth/reset-password",
        data: {
          "email": email,
          "code": codeOrToken, // الخادم يقبل code أو resetToken
          "newPassword": newPassword,
        },
      );

      if (response.statusCode == 200 && (response.data["success"] == true)) {
        // إعادة ربط OneSignal باليوزر بعد الحفظ المحلي
        await NotificationService.instance.rebindExternalUserId();
        return null;
      }

      return response.data["message"] ?? "فشل إعادة تعيين كلمة المرور";
    } on DioException catch (e) {
      return e.response?.data?["message"] ?? "خطأ في السيرفر";
    }
  }

  /// ✅ تسجيل الدخول
  Future<String?> login(String email, String password) async {
    try {
      // أرسل OneSignal player id مع بيانات تسجيل الدخول إن وُجد
      final playerId = await NotificationService.instance.getPlayerId();
      final payload = {
        "email": email,
        "password": password,
        if (playerId != null && playerId.isNotEmpty)
          "oneSignalPlayerId": playerId,
      };

      final response = await _apiService.dio.post("/auth/login", data: payload);

      if (response.statusCode == 200 && response.data["success"] == true) {
        final prefs = await SharedPreferences.getInstance();

        final data = response.data["data"];
        final user = data["user"];
        final token = data["token"];

        await prefs.setString("token", token);
        await prefs.setString("user", jsonEncode(user));

        return null;
      }

      return response.data["message"] ?? "فشل تسجيل الدخول";
    } on DioException catch (e) {
      final message =
          e.response?.data?["message"] ?? e.message ?? "خطأ في الشبكة";
      return message;
    } catch (e) {
      return "حدث خطأ غير متوقع";
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
    // فك الارتباط من OneSignal
    await NotificationService.instance.logoutOneSignal();
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
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _apiService.dio.post(
        "/auth/complete-profile",
        data: data,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        if (response.data["data"]?["user"] != null) {
          await prefs.setString(
            "user",
            jsonEncode(response.data["data"]["user"]),
          );
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
