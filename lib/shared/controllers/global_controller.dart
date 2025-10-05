import 'dart:async';
import 'package:get/get.dart';
import 'package:dirasiq/core/services/api_service.dart';
import 'package:dirasiq/core/services/auth_service.dart';
import 'package:dirasiq/core/services/notification_events.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';

/// 🧩 المتحكم العام لتطبيق Dirasiq
/// يدير بيانات المستخدم وعدد الإشعارات ويتفاعل مع النظام بالكامل.
class GlobalController extends GetxController {
  /// ✅ بيانات المستخدم (قد تكون null إذا لم يتم تسجيل الدخول)
  final user = Rxn<Map<String, dynamic>>();

  /// ✅ عدد الإشعارات غير المقروءة
  final unreadCount = 0.obs;

  /// ✅ خدمات النظام
  final _api = ApiService();
  final _auth = AuthService();

  /// ✅ الاستماعات للإشعارات القادمة
  StreamSubscription<void>? _notifSub;
  StreamSubscription<Map<String, dynamic>>? _payloadSub;

  @override
  void onInit() {
    super.onInit();
    _initialize();
  }

  /// تحميل المستخدم والإشعارات + إعداد المستمعين
  Future<void> _initialize() async {
    await loadUser();
    await loadUnread();

    // ✅ استمع لأي إشعار جديد
    _notifSub = NotificationEvents.instance.onNewNotification.listen((_) {
      loadUnread();
    });

    // ✅ استمع للإشعارات المحفوظة محليًا (payload)
    _payloadSub = NotificationEvents.instance.onNotificationPayload.listen((
      payload,
    ) {
      unreadCount.value = (unreadCount.value + 1).clamp(0, 999);
      // بعد قليل يحدث المزامنة الحقيقية من الخادم
      Future.delayed(const Duration(seconds: 1), loadUnread);
    });
  }

  /// ✅ تحميل بيانات المستخدم الحالية
  Future<void> loadUser() async {
    try {
      final u = await _auth.getUser();
      if (u != null) user.value = u;
    } catch (e) {
      // تجاهل الأخطاء الصامتة
    }
  }

  /// ✅ تحميل عدد الإشعارات غير المقروءة
  Future<void> loadUnread() async {
    try {
      final count = await _api.fetchUnreadNotificationsCount();
      unreadCount.value = count;
      _updateBadge(count);
    } catch (_) {
      // تجاهل الأخطاء (بدون تأثير)
    }
  }

  /// ✅ تسجيل الخروج الكامل (يُستخدم فقط عند الحاجة العامة)
  Future<void> logout() async {
    try {
      await _auth.logout();
      user.value = null;
      unreadCount.value = 0;
      _removeBadge();
    } catch (_) {}
  }

  @override
  void onClose() {
    _notifSub?.cancel();
    _payloadSub?.cancel();
    super.onClose();
  }

  Future<void> _updateBadge(int count) async {
    try {
      if (count > 0) {
        final isSupported = await FlutterAppBadger.isAppBadgeSupported();
        if (isSupported) FlutterAppBadger.updateBadgeCount(count);
      } else {
        _removeBadge();
      }
    } catch (_) {}
  }

  Future<void> _removeBadge() async {
    try {
      final isSupported = await FlutterAppBadger.isAppBadgeSupported();
      if (isSupported) FlutterAppBadger.removeBadge();
    } catch (_) {}
  }
}
