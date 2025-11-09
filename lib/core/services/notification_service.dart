import 'dart:convert';
import 'package:get/get.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  String? _playerId;
  String? get playerId => _playerId;

  Future<void> init() async {
    // ✅ تفعيل وضع التتبع
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

    // ✅ تهيئة OneSignal
    OneSignal.initialize("b136e33d-56f0-4fc4-ad08-8c8a534ca447");

    // ✅ طلب الإذن على iOS + Android
    await OneSignal.Notifications.requestPermission(true);

    // ✅ الحصول على playerId إذا موجود مسبقاً
    _updatePlayerId();

    // ✅ مراقبة تغيّر playerId
    OneSignal.User.pushSubscription.addObserver((state) async {
      _updatePlayerId();
    });

    // ✅ ربط المستخدم إذا كان مسجلاً مسبقاً
    await _bindSavedUserId();

    // ✅ عرض الإشعار حتى داخل التطبيق
    OneSignal.Notifications.addForegroundWillDisplayListener(
      (event) => event.notification.display(),
    );

    // ✅ عند الضغط على الإشعار
    OneSignal.Notifications.addClickListener((event) {
      _handleClick(event.notification.additionalData ?? {});
    });
  }

  // ###########################################################
  // ✅ رابط أساسي بين المستخدم و OneSignal
  // ###########################################################
  Future<void> loginUser(String userId) async {
    await OneSignal.login(userId);
    _updatePlayerId();
  }

  Future<void> logoutUser() async {
    await OneSignal.logout();
    _playerId = null;
  }

  Future<void> _bindSavedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString("user");
    if (raw == null) return;

    final user = jsonDecode(raw);
    final id = (user["id"] ?? user["_id"])?.toString();

    if (id != null && id.isNotEmpty) {
      await loginUser(id);
    }
  }

  Future<void> rebindExternalUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString("user");
    if (raw == null) {
      await logoutUser();
      return;
    }

    final user = jsonDecode(raw);
    final id = (user["id"] ?? user["_id"])?.toString();
    if (id != null && id.isNotEmpty) {
      await loginUser(id);
    } else {
      await logoutUser();
    }
  }

  Future<void> _updatePlayerId() async {
    final id = OneSignal.User.pushSubscription.id;
    if (id != null && id.isNotEmpty) {
      _playerId = id;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("onesignal_player_id", id);
    }
  }

  Future<String?> getPlayerId() async {
    return OneSignal.User.pushSubscription.id;
  }

  // ###########################################################
  // ✅ طلب الإذن عند الحاجة (يستخدم في الواجهات قبل فتح شاشة الإشعارات)
  // ###########################################################
  Future<void> requestPermissionIfNeeded() async {
    try {
      await OneSignal.Notifications.requestPermission(true);
      await _updatePlayerId();
    } catch (_) {}
  }

  // ###########################################################
  // ✅ التنقل داخل التطبيق عند الضغط على الإشعار
  // ###########################################################
  void _handleClick(Map<String, dynamic> data) {
    final route = data["route"]?.toString();

    if (route != null && route.isNotEmpty) {
      Get.toNamed(route, arguments: data);
      return;
    }

    // ✅ لو لا يوجد route → نفتح شاشة الإشعارات
    Get.toNamed("/notifications");
  }
}
