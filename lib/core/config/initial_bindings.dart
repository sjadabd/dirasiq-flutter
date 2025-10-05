import 'package:get/get.dart';
import 'package:dirasiq/core/services/api_service.dart';
import 'package:dirasiq/core/services/auth_service.dart';
import 'package:dirasiq/core/services/google_auth_service.dart';
import 'package:dirasiq/features/auth/controllers/auth_controller.dart';
import 'package:dirasiq/shared/controllers/global_controller.dart';

class InitialBindings extends Bindings {
  @override
  void dependencies() {
    // Services
    Get.lazyPut<ApiService>(() => ApiService(), fenix: true);
    Get.lazyPut<AuthService>(() => AuthService(), fenix: true);
    Get.lazyPut<GoogleAuthService>(() => GoogleAuthService(), fenix: true);

    // Controllers
    Get.lazyPut<AuthController>(() => AuthController(), fenix: true);
    Get.put<GlobalController>(GlobalController(), permanent: true);
  }
}


