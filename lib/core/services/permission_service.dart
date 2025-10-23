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

  static Future<bool> requestNotificationPermission() async {
    var status = await Permission.notification.status;
    if (status.isGranted) return true;
    if (status.isDenied) {
      final result = await Permission.notification.request();
      return result.isGranted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      await openAppSettings();
      status = await Permission.notification.status;
      return status.isGranted;
    }
    final result = await Permission.notification.request();
    return result.isGranted;
  }

  static Future<bool> requestLocationWhenInUsePermission() async {
    var status = await Permission.locationWhenInUse.status;
    if (status.isGranted) return true;
    if (status.isDenied) {
      final result = await Permission.locationWhenInUse.request();
      return result.isGranted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      await openAppSettings();
      status = await Permission.locationWhenInUse.status;
      return status.isGranted;
    }
    final result = await Permission.locationWhenInUse.request();
    return result.isGranted;
  }
}

