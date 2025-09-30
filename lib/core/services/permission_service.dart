import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  PermissionService._();

  /// يطلب إذن الكاميرا عند الحاجة ويعيد true إذا صار مصرح
  static Future<bool> requestCameraPermission() async {
    // تحقق من الحالة الحالية
    var status = await Permission.camera.status;
    if (status.isGranted) return true;

    // إذا كان مرفوض سابقاً بدون 'عدم الإظهار مجدداً' اطلبه مرة أخرى
    if (status.isDenied) {
      final result = await Permission.camera.request();
      return result.isGranted;
    }

    // إذا كان 'مرفوض دائماً' أو مقيّد، افتح إعدادات التطبيق
    if (status.isPermanentlyDenied || status.isRestricted) {
      await openAppSettings();
      // بعد فتح الإعدادات قد يعود المستخدم ويمنح الإذن
      status = await Permission.camera.status;
      return status.isGranted;
    }

    // حالات أخرى (محدودة على iOS 14+) اعتبر الطلب الاعتيادي
    final result = await Permission.camera.request();
    return result.isGranted;
  }
}
