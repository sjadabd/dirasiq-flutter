import 'dart:async';
import 'package:get/get.dart';
import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/core/services/auth_service.dart';
import 'package:mulhimiq/core/services/notification_events.dart';
import 'package:mulhimiq/features/teacher/chat/services/chat_unread_service.dart';
import 'package:app_badge_plus/app_badge_plus.dart';

/// 🧩 المتحكم العام لتطبيق mulhimiq
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
    // لا تقم بتحميل الإشعارات أو إعداد المستمعين إذا لم يكن المستخدم مسجلاً
    final loggedIn = await _auth.isLoggedIn();
    if (!loggedIn) {
      return;
    }
    await loadUnread();
    _startChatUnread();

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
      // تجنب الطلبات الشبكية إذا لم يكن مسجلاً
      final loggedIn = await _auth.isLoggedIn();
      if (!loggedIn) return;
      final count = await _api.fetchUnreadNotificationsCount();
      unreadCount.value = count;
      _updateBadge(count);
    } catch (_) {
      // تجاهل الأخطاء (بدون تأثير)
    }
  }

  /// صفّر شارة الإشعارات محلياً (بعد تعليم الكل كمقروء)
  void clearUnreadLocally() {
    unreadCount.value = 0;
    _removeBadge();
  }

  /// ✅ تسجيل الخروج الكامل (يُستخدم فقط عند الحاجة العامة)
  Future<void> logout() async {
    try {
      await _auth.logout();
      user.value = null;
      unreadCount.value = 0;
      _removeBadge();
      // Drop chat session state — sockets disconnect, counters zero.
      try {
        ChatUnreadService.instance.reset();
      } catch (_) {
        // Service may not be registered yet (cold logout edge case).
      }
    } catch (_) {}
  }

  /// Boots the chat-unread counter for the current user. Idempotent — the
  /// service short-circuits if already running with the same id.
  void _startChatUnread() {
    final u = user.value;
    if (u == null) return;
    final uid = (u['id'] ?? u['_id'])?.toString();
    if (uid == null || uid.isEmpty) return;
    try {
      // Fire-and-forget; the service handles its own errors.
      ChatUnreadService.instance.start(uid);
    } catch (_) {
      // Service not registered (cold-start edge case) — try again next tick.
    }
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
        final isSupported = await AppBadgePlus.isSupported();
        if (isSupported) AppBadgePlus.updateBadge(count);
      } else {
        _removeBadge();
      }
    } catch (_) {}
  }

  Future<void> _removeBadge() async {
    try {
      final isSupported = await AppBadgePlus.isSupported();
      if (isSupported) AppBadgePlus.updateBadge(0);
    } catch (_) {}
  }
}
