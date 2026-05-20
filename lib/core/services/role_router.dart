import 'package:get/get.dart';
import 'auth_service.dart';

/// Centralized "where do I go after successful auth" logic.
///
/// Single source of truth used by:
///   - SplashScreen (auto-login restoration)
///   - LoginScreen / AuthController (email+password login)
///   - GoogleAuthService (Google Sign-In)
///   - AppleAuthService (Apple Sign-In)
///   - RegisterScreen (post-signup)
///
/// Reads `userType` from the locally-stored user JSON (already saved by
/// AuthService.login or the OAuth services) and dispatches to the correct
/// role's home shell.
///
/// Behavior:
///   - student   → /home (existing student RootShell)
///   - teacher   → /teacher/home (new TeacherShell)
///   - super_admin → /login with an error toast (mobile is not the right surface)
///   - missing/unknown userType → /login as a fallback
class RoleRouter {
  static const String studentHomeRoute = '/home';
  static const String teacherHomeRoute = '/teacher/home';
  static const String loginRoute = '/login';
  static const String completeProfileRoute = '/complete-profile';

  /// Resolves the right route after auth and navigates with offAllNamed.
  ///
  /// [arguments] is passed through to the target route (used for example to
  /// surface a one-time welcome message).
  static Future<void> routeAfterAuth({Map<String, dynamic>? arguments}) async {
    final auth = AuthService();
    final user = await auth.getUser();
    if (user == null) {
      Get.offAllNamed(loginRoute);
      return;
    }

    final userType = (user['userType'] ?? user['user_type'] ?? '').toString();

    // Mobile app is for students + teachers only. Super admins use the web dashboard.
    if (userType == 'super_admin' || userType == 'admin') {
      await auth.logout();
      Get.snackbar(
        'غير متاح',
        'حسابات الإدارة تستخدم لوحة التحكم على الويب فقط.',
        snackPosition: SnackPosition.BOTTOM,
      );
      Get.offAllNamed(loginRoute);
      return;
    }

    if (userType == 'teacher') {
      // Teachers don't have the same "complete profile" gate as students
      // (their profile is completed during onboarding on the dashboard).
      // If we later need a teacher-side profile completion, switch on it here.
      Get.offAllNamed(teacherHomeRoute, arguments: arguments);
      return;
    }

    // Default: student. Honor the student profile-completion gate.
    final complete = await auth.isProfileComplete();
    if (!complete) {
      Get.offAllNamed(completeProfileRoute, arguments: arguments);
      return;
    }
    Get.offAllNamed(studentHomeRoute, arguments: arguments);
  }

  /// Returns the userType of the currently logged-in user (or null).
  /// Useful for screens that need to render role-specific UI without a redirect.
  static Future<String?> currentUserType() async {
    final user = await AuthService().getUser();
    if (user == null) return null;
    return (user['userType'] ?? user['user_type'])?.toString();
  }

  static Future<bool> isTeacher() async => (await currentUserType()) == 'teacher';
  static Future<bool> isStudent() async => (await currentUserType()) == 'student';
}
