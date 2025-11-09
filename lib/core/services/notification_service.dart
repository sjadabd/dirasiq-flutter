import 'dart:convert';
import 'dart:io';
import 'package:dirasiq/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:dirasiq/features/enrollments/screens/course_attendance_screen.dart';
import 'package:dirasiq/features/enrollments/screens/course_weekly_schedule_screen.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dirasiq/core/services/notification_events.dart';
import 'package:dirasiq/features/exams/screens/student_exams_screen.dart';
import 'package:dirasiq/features/invoices/screens/student_invoices_screen.dart';
import 'package:dirasiq/features/invoices/screens/invoice_details_screen.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  Future<void> init() async {
    // ✅ تهيئة OneSignal
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize(AppConfig.oneSignalAppId);
    // ✅ طلب صلاحيات
    await OneSignal.Notifications.requestPermission(true);
    // 🔍 طباعة حالة الاشتراك
    final sub = OneSignal.User.pushSubscription;
    debugPrint("------ OneSignal Debug ------");
    debugPrint("Player ID: ${sub.id}");
    debugPrint("Push Token: ${sub.token}");
    debugPrint("Subscribed: ${sub.optedIn}");
    debugPrint("--------------------------------");
    debugPrint('[OneSignal][diag]\n'
        '- playerId: ${sub.id}\n'
        '- token: ${sub.token}\n'
        '- optedIn: ${sub.optedIn}\n'
        '- platform: ${Platform.operatingSystem}\n'
        '- note:\n'
        '  id==null    -> الجهاز غير مسجل بعد (انتظر/أعد التهيئة)\n'
        '  token==null -> لا يوجد Push Token (تحقق من FCM/HMS/APNs)\n'
        '  optedIn==false -> الإذن مرفوض (اطلب الإذن/الإعدادات)');
    _dumpOneSignalState(tag: 'after_request_permission');

    // ✅ ربط المستخدم إذا موجود
    await _bindExternalUserIdIfAvailable();
    _dumpOneSignalState(tag: 'after_bind_if_available');

    // ✅ عرض الإشعارات حتى لو التطبيق مفتوح (Foreground)
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      event.preventDefault(); // منع السلوك الافتراضي
      event.notification.display(); // عرض الإشعار يدويًا
      try {
        final n = event.notification;
        final data = n.additionalData;
        // Compact single-line log for quick tracing
        // ignore: avoid_print
        print(
          '[OneSignal][fg] id=${n.notificationId} title=${n.title} hasData=${data != null}',
        );
      } catch (_) {}
      // أبلغ الواجهة بوجود إشعار جديد لتحديث الشارة والقوائم
      NotificationEvents.instance.emitNewNotification();
      try {
        final n = event.notification;
        final payload = <String, dynamic>{
          'id': n.notificationId,
          'title': n.title,
          'message': n.body,
          'status': 'sent',
          'createdAt': DateTime.now().toIso8601String(),
          'isRead': false,
          ...?n.additionalData?.map((k, v) => MapEntry(k.toString(), v)),
        };
        NotificationEvents.instance.emitNotificationPayload(payload);
      } catch (_) {}
      // في بعض الأحيان يتأخر حفظ الإشعار في الـ API لحظات بسيطة
      Future.delayed(const Duration(milliseconds: 600), () {
        NotificationEvents.instance.emitNewNotification();
      });
    });

    // ✅ عند الضغط على الإشعار
    OneSignal.Notifications.addClickListener((event) {
      try {
        final n = event.notification;
        // ignore: avoid_print
        print('[OneSignal][click] id=${n.notificationId} title=${n.title}');
      } catch (_) {}
      try {
        final data = event.notification.additionalData ?? {};
        _handleNotificationNavigation(data);
      } catch (_) {}
      // أبلغ الواجهة (قد تتغير حالة المقروء/فتح صفحة الإشعارات)
      NotificationEvents.instance.emitNewNotification();
      // حمولة فورية (قد يحتاج الواجهة للإضافة السريعة)
      try {
        final n = event.notification;
        final payload = <String, dynamic>{
          'id': n.notificationId,
          'title': n.title,
          'message': n.body,
          'status': 'sent',
          'createdAt': DateTime.now().toIso8601String(),
          'isRead': false,
          ...?n.additionalData?.map((k, v) => MapEntry(k.toString(), v)),
        };
        NotificationEvents.instance.emitNotificationPayload(payload);
      } catch (_) {}
      Future.delayed(const Duration(milliseconds: 400), () {
        NotificationEvents.instance.emitNewNotification();
      });
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
        // ignore: avoid_print
        print('[OneSignal] login userId=$userId');
        await OneSignal.login(userId);
        _dumpOneSignalState(tag: 'after_login');
      }
    } catch (_) {}
  }

  Future<void> rebindExternalUserId() async {
    // ignore: avoid_print
    print('[OneSignal] rebindExternalUserId start');
    await _bindExternalUserIdIfAvailable();
    _dumpOneSignalState(tag: 'after_rebind');
  }

  Future<void> logoutOneSignal() async {
    try {
      // ignore: avoid_print
      print('[OneSignal] logout');
      await OneSignal.logout();
      _dumpOneSignalState(tag: 'after_logout');
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
    final nested = (data['data'] is Map)
        ? Map<String, dynamic>.from(data['data'] as Map)
        : <String, dynamic>{};
    final courseId = (data['courseId'] ?? nested['courseId'])?.toString();
    final url = data['url']?.toString();
    final type = data['type']?.toString();
    final hasAttendanceMarkers =
        data.containsKey('status') ||
        data.containsKey('attendanceStatus') ||
        data.containsKey('date') ||
        nested.containsKey('status') ||
        nested.containsKey('attendanceStatus') ||
        nested.containsKey('date');

    if (route != null && route.isNotEmpty) {
      Get.toNamed(route, arguments: data);
      return;
    }

    // Exams routing: go directly to exams list (daily/monthly) instead of opening notifications list
    final typeLower = type?.toLowerCase();
    final payloadExamType =
        (data['exam_type'] ??
                data['examType'] ??
                data['kind'] ??
                nested['exam_type'] ??
                nested['examType'])
            ?.toString()
            .toLowerCase();
    final inferredExamType =
        (data['type'] ??
                data['category'] ??
                nested['type'] ??
                nested['category'])
            ?.toString()
            .toLowerCase();
    final isExamNotification =
        (typeLower?.contains('exam') ?? false) ||
        (payloadExamType == 'daily' || payloadExamType == 'monthly') ||
        (inferredExamType == 'exam');
    if (isExamNotification) {
      final isMonthly =
          payloadExamType == 'monthly' || typeLower == 'monthly_exam';
      if (isMonthly) {
        Get.to(
          () => const StudentExamsScreen(
            fixedType: 'monthly',
            title: 'امتحانات شهرية',
          ),
        );
      } else {
        Get.to(
          () => const StudentExamsScreen(
            fixedType: 'daily',
            title: 'امتحانات يومية',
          ),
        );
      }
      return;
    }

    // Invoice routing
    final invoiceId =
        (data['invoiceId'] ??
                nested['invoiceId'] ??
                data['invoice_id'] ??
                nested['invoice_id'])
            ?.toString();
    final subType =
        (data['subType'] ??
                data['sub_type'] ??
                nested['subType'] ??
                nested['sub_type'])
            ?.toString()
            .toLowerCase();
    final isInvoiceBySubtype = const {
      'invoice_created',
      'invoice_updated',
      'installment_due',
      'installment_paid',
    }.contains(subType);
    final isInvoiceByType =
        (typeLower?.contains('invoice') ?? false) ||
        typeLower == 'payment_reminder';
    if (isInvoiceBySubtype || isInvoiceByType) {
      if (invoiceId != null && invoiceId.isNotEmpty) {
        Get.to(() => InvoiceDetailsScreen(invoiceId: invoiceId));
      } else {
        Get.to(() => const StudentInvoicesScreen());
      }
      return;
    }

    // If it's a course update, decide destination by payload markers
    if (type == 'course_update' && courseId != null && courseId.isNotEmpty) {
      if (hasAttendanceMarkers) {
        // attendance status update
        Get.to(() => CourseAttendanceScreen(courseId: courseId));
      } else {
        // schedule update
        Get.to(() => CourseWeeklyScheduleScreen(courseId: courseId));
      }
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

  void _dumpOneSignalState({required String tag}) {
    try {
      final sub = OneSignal.User.pushSubscription;
      // ignore: avoid_print
      print(
        '[OneSignal][$tag] id=${sub.id} token=${sub.token} optedIn=${sub.optedIn} platform=${Platform.operatingSystem}',
      );
    } catch (_) {}
  }
}
