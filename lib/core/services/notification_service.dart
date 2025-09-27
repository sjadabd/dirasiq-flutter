import 'dart:convert';
import 'package:dirasiq/core/config/app_config.dart';
import 'package:get/get.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  Future<void> init() async {
    // ✅ تهيئة OneSignal
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize(AppConfig.oneSignalAppId);

    // ✅ طلب صلاحيات
    await OneSignal.Notifications.requestPermission(true);

    // ✅ ربط المستخدم إذا موجود
    await _bindExternalUserIdIfAvailable();

    // ✅ عرض الإشعارات حتى لو التطبيق مفتوح (Foreground)
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      event.preventDefault(); // منع السلوك الافتراضي
      event.notification.display(); // عرض الإشعار يدويًا
    });

    // ✅ عند الضغط على الإشعار
    OneSignal.Notifications.addClickListener((event) {
      try {
        final data = event.notification.additionalData ?? {};
        _handleNotificationNavigation(data);
      } catch (_) {}
    });
  }

  Future<void> requestPermissionIfNeeded() async {
    await OneSignal.Notifications.requestPermission(true);
  }

  Future<void> _bindExternalUserIdIfAvailable() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');
      if (userJson == null) return;
      final user = jsonDecode(userJson) as Map<String, dynamic>;
      final userId = (user['id'] ?? user['_id'])?.toString();
      if (userId != null && userId.isNotEmpty) {
        await OneSignal.login(userId);
      }
    } catch (_) {}
  }

  Future<void> rebindExternalUserId() async {
    await _bindExternalUserIdIfAvailable();
  }

  Future<void> logoutOneSignal() async {
    try {
      await OneSignal.logout();
    } catch (_) {}
  }

  Future<String?> getPlayerId() async {
    try {
      final id = OneSignal.User.pushSubscription.id;
      return id;
    } catch (_) {
      return null;
    }
  }

  void _handleNotificationNavigation(Map<String, dynamic> data) {
    final route = data['route']?.toString();
    final courseId = data['courseId']?.toString();
    final url = data['url']?.toString();

    if (route != null && route.isNotEmpty) {
      Get.toNamed(route, arguments: data);
      return;
    }

    if (courseId != null && courseId.isNotEmpty) {
      Get.toNamed('/course-details', arguments: courseId);
      return;
    }

    if (url != null && url.isNotEmpty) {
      // ممكن تضيف صفحة WebView هنا
      // Get.toNamed('/webview', arguments: url);
      return;
    }

    // ✅ افتراضي: فتح شاشة الإشعارات
    Get.toNamed('/notifications');
  }
}
