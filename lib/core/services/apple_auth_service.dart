import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:dirasiq/core/config/app_config.dart';
import 'package:dirasiq/core/services/notification_service.dart';
import 'dart:io' show Platform;

class AppleAuthService {
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

  Future<String?> signInWithApple(String userType) async {
    try {
      final playerId = await NotificationService.instance.getPlayerId();

      /// 🧩 إعداد خيارات الويب فقط لأجهزة Android
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: Platform.isAndroid
            ? WebAuthenticationOptions(
                clientId: 'com.mulhimiq.auth', // نفس APPLE_CLIENT_ID
                redirectUri: Uri.parse(
                  'https://api.mulhimiq.com/api/auth/apple-redirect',
                ),
              )
            : null,
      );

      final payload = {
        "identityToken": credential.identityToken,
        "authorizationCode": credential.authorizationCode,
        "userType": userType,
        if (credential.givenName != null) "firstName": credential.givenName,
        if (credential.familyName != null) "lastName": credential.familyName,
        if (playerId != null && playerId.isNotEmpty)
          "oneSignalPlayerId": playerId,
      };

      // إرسال الطلب مع دعم UTF-8
      final response = await _dio.post(
        "/apple-auth",
        data: payload,
        options: Options(responseType: ResponseType.bytes),
      );

      final decodedBody = utf8.decode(response.data);
      final jsonResponse = jsonDecode(decodedBody);
      print('✅ AppleAuth response: $jsonResponse');

      if (response.statusCode == 200 && jsonResponse["success"] == true) {
        final prefs = await SharedPreferences.getInstance();
        final data = jsonResponse["data"];
        final user = data["user"];
        final token = data["token"];

        await prefs.setString("token", token);
        await prefs.setString("user", jsonEncode(user));
        await NotificationService.instance.rebindExternalUserId();
        return null;
      }

      print('❌ Server responded with error: ${jsonResponse["message"]}');
      return jsonResponse["message"] ?? "فشل تسجيل الدخول عبر Apple";
    } on DioException catch (e) {
      print('❌ Dio Error: ${e.message}');
      print('❌ Dio Response: ${e.response?.data}');
      return "خطأ في الشبكة أثناء الاتصال بالخادم";
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return "تم إلغاء العملية";
      }
      return "فشل تسجيل الدخول عبر Apple";
    } catch (e, stack) {
      print('💥 Unexpected error in AppleAuthService: $e');
      print(stack);
      return "حدث خطأ غير متوقع";
    }
  }
}
