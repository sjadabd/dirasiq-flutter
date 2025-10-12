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
        "577832490185-gnglmomcjlkn9us9fm5qofc2geiau296.apps.googleusercontent.com",
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
      print("STEP 1: بدء تسجيل الدخول عبر Google...");
      final account = await _googleSignIn.signIn();
      print("STEP 2: account = ${account?.email}");

      if (account == null) {
        return "تم إلغاء العملية";
      }

      final auth = await account.authentication;
      print("STEP 3: حصلنا على التوكن ✅");

      final playerId = await NotificationService.instance.getPlayerId();
      print("STEP 4: playerId = $playerId");

      final payload = {
        "googleToken": auth.idToken,
        "userType": userType,
        if (playerId != null && playerId.isNotEmpty)
          "oneSignalPlayerId": playerId,
      };
      print("STEP 5: payload = $payload");

      final response = await _dio.post("/google-auth", data: payload);
      print("STEP 6: response = ${response.data}");

      if (response.statusCode == 200 && response.data["success"] == true) {
        final prefs = await SharedPreferences.getInstance();
        final data = response.data["data"];
        final user = data["user"];
        final token = data["token"];

        await prefs.setString("token", token);
        await prefs.setString("user", jsonEncode(user));
        await NotificationService.instance.rebindExternalUserId();
        print("STEP 7: تسجيل الدخول تم بنجاح ✅");
        return null;
      }

      return response.data["message"] ?? "فشل تسجيل الدخول عبر Google";
    } on DioException catch (e) {
      print("🔥 DioException: ${e.response?.data ?? e.message}");
      return e.response?.data?["message"] ?? "خطأ في الشبكة";
    } catch (e, st) {
      print("❌ Unexpected error during Google Sign-In: $e");
      print("StackTrace: $st");
      return "حدث خطأ غير متوقع";
    }
  }

  Future<void> signOut() => _googleSignIn.signOut();
}
