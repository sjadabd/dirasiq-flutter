import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: "347174406018-8q0gaa0spce1hr7rsa1okge2or0sd6br.apps.googleusercontent.com",
  );

  final Dio _dio = Dio(
    BaseOptions(baseUrl: "http://192.168.68.103:3000/api/auth"), // ✅ تأكد من المسار
  );

  Future<bool> signInWithGoogle(String userType) async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        print("❌ المستخدم ألغى تسجيل الدخول");
        return false;
      }

      final auth = await account.authentication;

      final response = await _dio.post("/google-auth", data: {
        "googleToken": auth.idToken,
        "userType": userType,
      });

      print("📩 استجابة الخادم: ${response.data}");

      if (response.statusCode == 200 && response.data["success"] == true) {
        final prefs = await SharedPreferences.getInstance();

        final data = response.data["data"];
        final user = data["user"];
        final token = data["token"];

        // 🟢 تخزين التوكن
        await prefs.setString("token", token);

        // 🟢 تخزين بيانات المستخدم كلها كـ JSON String
        await prefs.setString("user", jsonEncode(user));

        print("👤 المستخدم: $user");
        print("🔑 التوكن: $token");

        return true; // ✅ تسجيل الدخول ناجح
      }

      return false;
    } catch (e) {
      print("Google SignIn Error: $e");
      return false;
    }
  }

  Future<void> signOut() => _googleSignIn.signOut();
}
