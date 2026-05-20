import 'package:get/get.dart';
import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/core/services/auth_service.dart';
import 'package:mulhimiq/core/services/google_auth_service.dart';
import 'package:mulhimiq/core/services/apple_auth_service.dart';
import 'package:mulhimiq/features/auth/controllers/auth_controller.dart';
import 'package:mulhimiq/features/teacher/chat/services/chat_unread_service.dart';
import 'package:mulhimiq/shared/controllers/global_controller.dart';

class InitialBindings extends Bindings {
  @override
  void dependencies() {
    // Services
    Get.lazyPut<ApiService>(() => ApiService(), fenix: true);
    Get.lazyPut<AuthService>(() => AuthService(), fenix: true);
    Get.lazyPut<GoogleAuthService>(() => GoogleAuthService(), fenix: true);
    Get.lazyPut<AppleAuthService>(() => AppleAuthService(), fenix: true);

    // Session-long chat unread counter — drives the navbar badge across
    // every screen. Permanent so it survives route changes; GlobalController
    // boots it once the user is loaded.
    Get.put<ChatUnreadService>(ChatUnreadService(), permanent: true);

    // Controllers
    Get.lazyPut<AuthController>(() => AuthController(), fenix: true);
    Get.put<GlobalController>(GlobalController(), permanent: true);
  }
}
