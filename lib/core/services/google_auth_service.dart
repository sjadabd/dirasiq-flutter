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
        "86749213367-bu708isbvui40kq5e4r84n8kk6ggr14g.apps.googleusercontent.com",
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
      await _googleSignIn.signOut();
      try {
        await _googleSignIn.disconnect();
      } catch (_) {}
      final account = await _googleSignIn.signIn();

      if (account == null) {
        return "تم إلغاء العملية";
      }

      final auth = await account.authentication;

      final playerId = await NotificationService.instance.getPlayerId();

      final payload = {
        "googleToken": auth.idToken,
        "userType": userType,
        if (playerId != null && playerId.isNotEmpty)
          "oneSignalPlayerId": playerId,
      };

      final response = await _dio.post("/google-auth", data: payload);

      if (response.statusCode == 200 && response.data["success"] == true) {
        final prefs = await SharedPreferences.getInstance();
        final data = response.data["data"];
        final user = data["user"];
        final token = data["token"];

        await prefs.setString("token", token);
        await prefs.setString("user", jsonEncode(user));
        await NotificationService.instance.rebindExternalUserId();
        return null;
      }

      return response.data["message"] ?? "فشل تسجيل الدخول عبر Google";
    } on DioException catch (e) {
      return e.response?.data?["message"] ?? "خطأ في الشبكة";
    } catch (e) {
      return "حدث خطأ غير متوقع";
    }
  }

  Future<void> signOut() => _googleSignIn.signOut();
}
