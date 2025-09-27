import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dirasiq/core/config/app_config.dart'; // ✅ استدعاء AppConfig
import 'package:dirasiq/core/services/notification_service.dart';

class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId:
        "347174406018-8q0gaa0spce1hr7rsa1okge2or0sd6br.apps.googleusercontent.com",
  );

  final Dio _dio = Dio(
    BaseOptions(
      // ✅ استخدم AppConfig بدل كتابة الرابط يدويًا
      baseUrl: "${AppConfig.apiBaseUrl}/auth",
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
    ),
  );

  /// ✅ تسجيل الدخول بجوجل
  Future<String?> signInWithGoogle(String userType) async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        return "تم إلغاء العملية";
      }

      final auth = await account.authentication;
      // أرسل OneSignal player id مع تسجيل دخول Google إن وُجد
      final playerId = await NotificationService.instance.getPlayerId();
      final payload = {
        "googleToken": auth.idToken,
        "userType": userType,
        if (playerId != null && playerId.isNotEmpty)
          "oneSignalPlayerId": playerId,
      };

      final response = await _dio.post(
        "/google-auth",
        data: payload,
      );

      if (response.statusCode == 200 && response.data["success"] == true) {
        final prefs = await SharedPreferences.getInstance();

        final data = response.data["data"];
        final user = data["user"];
        final token = data["token"];

        await prefs.setString("token", token);
        await prefs.setString("user", jsonEncode(user));

        // إعادة ربط OneSignal باليوزر بعد الحفظ المحلي
        await NotificationService.instance.rebindExternalUserId();
        return null; // ✅ نجاح
      }

      return response.data["message"] ?? "فشل تسجيل الدخول عبر Google";
    } on DioException catch (e) {
      final message =
          e.response?.data?["message"] ?? e.message ?? "خطأ في الشبكة";
      return message;
    } catch (e) {
      return "حدث خطأ غير متوقع";
    }
  }

  Future<void> signOut() => _googleSignIn.signOut();
}
