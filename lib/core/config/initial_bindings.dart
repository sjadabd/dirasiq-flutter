import 'package:get/get.dart';
import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/core/services/auth_service.dart';
import 'package:mulhimiq/core/services/google_auth_service.dart';
import 'package:mulhimiq/core/services/apple_auth_service.dart';
import 'package:mulhimiq/features/auth/controllers/auth_controller.dart';
import 'package:mulhimiq/shared/controllers/global_controller.dart';

class InitialBindings extends Bindings {
  @override
  void dependencies() {
    // Services
    Get.lazyPut<ApiService>(() => ApiService(), fenix: true);
    Get.lazyPut<AuthService>(() => AuthService(), fenix: true);
    Get.lazyPut<GoogleAuthService>(() => GoogleAuthService(), fenix: true);
    Get.lazyPut<AppleAuthService>(() => AppleAuthService(), fenix: true);

    // Controllers
    Get.lazyPut<AuthController>(() => AuthController(), fenix: true);
    Get.put<GlobalController>(GlobalController(), permanent: true);
  }
}
