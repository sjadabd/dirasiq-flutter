import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mulhimiq/core/config/app_config.dart';
import 'package:mulhimiq/core/services/notification_service.dart';

class GoogleAuthService {
  String? _lastEmail;
  String? get lastEmail => _lastEmail;

  // ✅ Google Sign-In setup for Android + iOS
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],

    // ✅ مهم جداً من أجل iOS
    clientId:
        "765386230641-a2iko4308ouljpb9kk0ut0shpl9vvqm0.apps.googleusercontent.com",

    // ✅ يجب أن يكون Web Client ID كي يتم التوثيق بين السيرفر وجوجل
    serverClientId:
        "765386230641-1be5i4mejr0mql13ib6bk27dj0uq7n8f.apps.googleusercontent.com",
  );

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: "${AppConfig.apiBaseUrl}/auth",
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
    ),
  );

  /// ✅ تسجيل الدخول عبر Google
  Future<String?> signInWithGoogle(String userType) async {
    try {
      await _googleSignIn.signOut();
      try {
        await _googleSignIn.disconnect();
      } catch (_) {}

      final account = await _googleSignIn.signIn();
      if (account == null) return "تم إلغاء العملية";

      _lastEmail = account.email;
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

        await NotificationService.instance.loginUser((user["_id"] ?? user["id"]).toString());

        return null;
      }

      final message =
          response.data["message"]?.toString() ?? "فشل تسجيل الدخول عبر Google";
      if (message.contains("غير مفعل")) return "EMAIL_VERIFICATION_REQUIRED";
      return message;
    } on DioException catch (e) {
      final msg = e.response?.data?["message"]?.toString() ?? "خطأ في الشبكة";
      if (msg.contains("غير مفعل")) return "EMAIL_VERIFICATION_REQUIRED";
      return msg;
    } catch (e) {
      return "حدث خطأ غير متوقع";
    }
  }

  Future<void> signOut() => _googleSignIn.signOut();
}
