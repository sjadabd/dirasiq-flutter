import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:dirasiq/core/config/app_config.dart';

class ApiService {
  late final Dio _dio;

  static String getBaseUrl() {
    const String baseUrl = AppConfig.apiBaseUrl;

    if (Platform.isAndroid) {
      return baseUrl;
    } else if (Platform.isIOS) {
      return baseUrl;
    } else {
      return baseUrl;
    }
  }

  // =============================
  // امتحانات الطالب
  // =============================

  /// جلب قائمة الامتحانات للطالب
  Future<Map<String, dynamic>> fetchStudentExams({
    int page = 1,
    int limit = 10,
    String? type, // daily | weekly | monthly | final ... (حسب السيرفر)
  }) async {
    try {
      final qp = {
        "page": page,
        "limit": limit,
        if (type != null && type.isNotEmpty) "type": type,
      };
      final response = await _dio.get(
        "/student/exams",
        queryParameters: qp,
      );
      if (response.statusCode == 200 && response.data["success"] == true) {
        return Map<String, dynamic>.from(response.data);
      }
      throw Exception(response.data["message"] ?? "فشل تحميل الامتحانات");
    } catch (e) {
      throw Exception("❌ خطأ أثناء تحميل الامتحانات: $e");
    }
  }

  /// جلب تفاصيل امتحان
  Future<Map<String, dynamic>> fetchStudentExamById(String examId) async {
    try {
      final response = await _dio.get("/student/exams/$examId");
      if (response.statusCode == 200 && response.data["success"] == true) {
        return Map<String, dynamic>.from(response.data["data"]);
      }
      throw Exception(response.data["message"] ?? "فشل تحميل تفاصيل الامتحان");
    } catch (e) {
      throw Exception("❌ خطأ أثناء تحميل تفاصيل الامتحان: $e");
    }
  }

  /// درجتي في امتحان محدد
  Future<Map<String, dynamic>?> fetchStudentExamMyGrade(String examId) async {
    try {
      final response = await _dio.get("/student/exams/$examId/my-grade");
      if (response.statusCode == 200 && response.data["success"] == true) {
        final data = response.data["data"];
        if (data is Map<String, dynamic>) {
          return Map<String, dynamic>.from(data);
        }
        return null;
      }
      throw Exception(response.data["message"] ?? "فشل تحميل درجتي");
    } catch (e) {
      throw Exception("❌ خطأ أثناء تحميل درجتي: $e");
    }
  }

  /// تقرير الامتحانات حسب النوع
  Future<List<Map<String, dynamic>>> fetchStudentExamReportByType({
    required String type, // monthly | daily | ...
  }) async {
    try {
      final response = await _dio.get(
        "/student/exams/report/by-type",
        queryParameters: {"type": type},
      );
      if (response.statusCode == 200 && response.data["success"] == true) {
        final list = response.data["data"] as List;
        return List<Map<String, dynamic>>.from(list);
      }
      throw Exception(response.data["message"] ?? "فشل تحميل التقرير");
    } catch (e) {
      throw Exception("❌ خطأ أثناء تحميل التقرير: $e");
    }
  }

  /// ✅ جلب إرسال الطالب الحالي لهذا الواجب
  Future<Map<String, dynamic>?> fetchMyAssignmentSubmission(String assignmentId) async {
    try {
      final response = await _dio.get("/student/assignments/$assignmentId/submission");
      if (response.statusCode == 200 && response.data["success"] == true) {
        final data = response.data["data"];
        if (data is Map<String, dynamic>) {
          return Map<String, dynamic>.from(data);
        }
        return null;
      }
      throw Exception(response.data["message"] ?? "فشل تحميل إرسال الطالب");
    } on DioException catch (e) {
      final res = e.response;
      if (res != null) {
        final data = res.data is Map<String, dynamic>
            ? res.data as Map<String, dynamic>
            : <String, dynamic>{};
        final serverMsg = (data["message"] ?? "فشل تحميل إرسال الطالب").toString();
        throw Exception(serverMsg);
      }
      throw Exception("❌ خطأ أثناء تحميل إرسال الطالب: ${e.message}");
    } catch (e) {
      throw Exception("❌ خطأ أثناء تحميل إرسال الطالب: $e");
    }
  }

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: getBaseUrl(),
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
      ),
    );

    // ✅ Interceptors
    _dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestBody: true,
        responseBody: true,
        error: true,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final prefs = await SharedPreferences.getInstance();
            final token = prefs.getString('token');
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } catch (_) {}
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          final status = e.response?.statusCode;
          // Only force logout on 401 (unauthorized). 403 may be a business rule (e.g., not enrolled),
          // so we should NOT clear auth or navigate away on 403.
          if (status == 401) {
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('token');
              await prefs.remove('user');
            } catch (_) {}
            if (Get.currentRoute != '/login') {
              Get.offAllNamed('/login');
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  Dio get dio => _dio;

  // =============================
  // تقييمات الطالب
  // =============================

  /// جلب قائمة تقييمات الطالب مع فلاتر التاريخ والترقيم
  Future<Map<String, dynamic>> fetchStudentEvaluations({
    String? from, // YYYY-MM-DD
    String? to,   // YYYY-MM-DD
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final qp = {
        "page": page,
        "limit": limit,
        if (from != null && from.isNotEmpty) "from": from,
        if (to != null && to.isNotEmpty) "to": to,
      };
      final response = await _dio.get(
        "/student/evaluations",
        queryParameters: qp,
      );
      if (response.statusCode == 200 && response.data["success"] == true) {
        // يرجع: { success, data: [...], pagination: {...} }
        return Map<String, dynamic>.from(response.data);
      }
      throw Exception(response.data["message"] ?? "فشل تحميل التقييمات");
    } catch (e) {
      throw Exception("❌ خطأ أثناء تحميل التقييمات: $e");
    }
  }

  /// جلب تفاصيل تقييم واحد
  Future<Map<String, dynamic>> fetchStudentEvaluationById(String id) async {
    try {
      final response = await _dio.get("/student/evaluations/$id");
      if (response.statusCode == 200 && response.data["success"] == true) {
        return Map<String, dynamic>.from(response.data["data"]);
      }
      throw Exception(response.data["message"] ?? "فشل تحميل تفاصيل التقييم");
    } catch (e) {
      throw Exception("❌ خطأ أثناء تحميل تفاصيل التقييم: $e");
    }
  }

  /// ✅ جلب الدورات المسجّل بها الطالب
  Future<Map<String, dynamic>> fetchStudentEnrollments({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await _dio.get(
        "/student/enrollments",
        queryParameters: {"page": page, "limit": limit},
      );

      if (response.statusCode == 200 && response.data["success"] == true) {
        // يرجع: data: [ ... ], pagination: {...}
        return Map<String, dynamic>.from(response.data);
      } else {
        throw Exception(
          response.data["message"] ?? "فشل تحميل الدورات المسجّل بها",
        );
      }
    } catch (e) {
      throw Exception("❌ خطأ أثناء تحميل الدورات المسجّل بها: $e");
    }
  }

  /// ✅ جلب الصفوف (للطلاب)
  Future<List<Map<String, dynamic>>> fetchGrades() async {
    try {
      final response = await _dio.get("/grades/all-student");
      if (response.statusCode == 200 && response.data["success"] == true) {
        return List<Map<String, dynamic>>.from(response.data["data"]);
      } else {
        throw Exception(response.data["message"] ?? "فشل تحميل الصفوف");
      }
    } catch (e) {
      throw Exception("❌ خطأ أثناء تحميل الصفوف: $e");
    }
  }

  /// ✅ جلب الصفوف للمعلمين
  Future<List<Map<String, dynamic>>> fetchTeacherGrades() async {
    try {
      final response = await _dio.get("/grades/all-teacher");
      if (response.statusCode == 200 && response.data["success"] == true) {
        return List<Map<String, dynamic>>.from(response.data["data"]);
      } else {
        throw Exception(response.data["message"] ?? "فشل تحميل صفوف المعلم");
      }
    } catch (e) {
      throw Exception("❌ خطأ أثناء تحميل صفوف المعلم: $e");
    }
  }

  /// ✅ جلب الدورات المقترحة للطالب
  Future<List<Map<String, dynamic>>> fetchSuggestedCourses({
    int page = 1,
    int limit = 10,
    double? maxDistance,
  }) async {
    try {
      final response = await _dio.get(
        "/student/courses/suggested",
        queryParameters: {
          "page": page,
          "limit": limit,
          "maxDistance": maxDistance, // يرسل null إذا ما محدد
        },
      );

      if (response.statusCode == 200 && response.data["success"] == true) {
        // ✅ المسار الصحيح: data.courses
        final courses = response.data["data"]["courses"] as List;
        return List<Map<String, dynamic>>.from(courses);
      } else {
        throw Exception(response.data["message"] ?? "فشل تحميل الدورات");
      }
    } catch (e) {
      throw Exception("❌ خطأ أثناء تحميل الدورات: $e");
    }
  }

  /// ✅ جلب تفاصيل دورة معينة للطالب
  Future<Map<String, dynamic>> fetchCourseDetails(String courseId) async {
    try {
      final response = await _dio.get("/student/courses/$courseId");

      if (response.statusCode == 200 && response.data["success"] == true) {
        // ✅ البيانات موجودة في response.data["data"]
        return Map<String, dynamic>.from(response.data["data"]);
      } else {
        throw Exception(response.data["message"] ?? "فشل تحميل تفاصيل الدورة");
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404) {
        // دورة غير متاحة/غير موجودة
        throw Exception("الدورة غير متاحة");
      }
      throw Exception("❌ خطأ أثناء تحميل تفاصيل الدورة: ${e.message}");
    } catch (e) {
      throw Exception("❌ خطأ أثناء تحميل تفاصيل الدورة: $e");
    }
  }

  /// ✅ جلب آخر الأخبار (ثابت: newsType = mobile)
  Future<List<Map<String, dynamic>>> fetchLatestNews({
    int page = 1,
    int limit = 5,
    String? search,
    bool isActive = true,
  }) async {
    try {
      final response = await _dio.get(
        "/news",
        queryParameters: {
          "page": page,
          "limit": limit,
          "search": search ?? "null",
          "isActive": isActive,
          "newsType": "mobile", // ثابت
        },
      );

      if (response.statusCode == 200 && response.data["success"] == true) {
        final newsList = response.data["data"] as List; // ✅ صح هنا
        return List<Map<String, dynamic>>.from(newsList);
      } else {
        throw Exception(response.data["message"] ?? "فشل تحميل الأخبار");
      }
    } catch (e) {
      throw Exception("❌ خطأ أثناء تحميل الأخبار: $e");
    }
  }

  /// ✅ جلب إشعارات المستخدم الحالي
  Future<Map<String, dynamic>> fetchMyNotifications({
    int page = 1,
    int limit = 10,
    String? type, // homework, message, report, notice, installments, attendance, daily_summary, birthday, daily_exam
  }) async {
    try {
      final qp = {
        "page": page,
        "limit": limit,
        // Backend expects 'subType' as the key
        if (type != null) "subType": type,
      };
      final response = await _dio.get(
        "/notifications/user/my-notifications",
        queryParameters: qp,
      );

      if (response.statusCode == 200 && response.data["success"] == true) {
        return Map<String, dynamic>.from(response.data["data"]);
      } else {
        throw Exception(response.data["message"] ?? "فشل تحميل الإشعارات");
      }
    } catch (e) {
      throw Exception("❌ خطأ أثناء تحميل الإشعارات: $e");
    }
  }

  /// ✅ تعليم إشعار كمقروء
  Future<void> markNotificationAsRead(String id) async {
    try {
      final response = await _dio.put("/notifications/$id/read");
      if (response.statusCode != 200 || response.data["success"] != true) {
        throw Exception(response.data["message"] ?? "فشل تحديث حالة الإشعار");
      }
    } catch (e) {
      throw Exception("❌ خطأ أثناء تحديث حالة الإشعار: $e");
    }
  }

  /// ✅ عدد الإشعارات غير المقروءة (حل مرن حتى لو الواجهة لا تدعم العد مباشرة)
  Future<int> fetchUnreadNotificationsCount() async {
    try {
      // 1) اطلب بفلترة لتقليل الحجم لكن لا تعتمد عليها
      final response = await _dio.get(
        "/notifications/user/my-notifications",
        queryParameters: {
          "page": 1,
          "limit": 100,
          "status": "sent", // اعتبرها غير مقروءة في نظامك
        },
      );

      if (response.statusCode == 200 && response.data["success"] == true) {
        final data = Map<String, dynamic>.from(response.data["data"]);
        final list = List<Map<String, dynamic>>.from(
          (data['items'] ?? data['notifications'] ?? data['data'] ?? [])
              as List,
        );
        // احسب محلياً لضمان الدقة حتى لو تجاهل الخادم الفلترة
        int unread = 0;
        for (final n in list) {
          final status = (n['status'] ?? '').toString().toLowerCase();
          final isReadFlag = (n['is_read'] == true) || (n['isRead'] == true);
          final hasReadAt = (n['read_at'] != null) || (n['readAt'] != null);
          final hasUserReadAt =
              (n['user_read_at'] != null) || (n['userReadAt'] != null);
          final isUnreadFlag =
              (n['is_unread'] == true) || (n['isUnread'] == true);

          final isRead =
              isReadFlag ||
              hasReadAt ||
              hasUserReadAt ||
              status == 'read' ||
              status == 'seen' ||
              status == 'opened';

          final isUnread = isUnreadFlag || !isRead;
          if (isUnread) unread++;
        }
        return unread;
      } else {
        return 0;
      }
    } catch (_) {
      // تجاهل ونحاول طريقة بديلة بالأسفل
    }

    // 2) خطة بديلة: اجلب بدون فلترة واحسب محلياً
    try {
      final response = await _dio.get(
        "/notifications/user/my-notifications",
        queryParameters: {"page": 1, "limit": 100},
      );
      if (response.statusCode == 200 && response.data["success"] == true) {
        final data = Map<String, dynamic>.from(response.data["data"]);
        final list = List<Map<String, dynamic>>.from(
          (data['items'] ?? data['notifications'] ?? data['data'] ?? [])
              as List,
        );
        int unread = 0;
        for (final n in list) {
          final status = (n['status'] ?? '').toString().toLowerCase();
          final isReadFlag = (n['is_read'] == true) || (n['isRead'] == true);
          final hasReadAt = (n['read_at'] != null) || (n['readAt'] != null);
          final hasUserReadAt =
              (n['user_read_at'] != null) || (n['userReadAt'] != null);
          final isUnreadFlag =
              (n['is_unread'] == true) || (n['isUnread'] == true);

          final isRead =
              isReadFlag ||
              hasReadAt ||
              hasUserReadAt ||
              status == 'read' ||
              status == 'seen' ||
              status == 'opened';

          final isUnread = isUnreadFlag || !isRead;
          if (isUnread) unread++;
        }
        return unread;
      }
    } catch (_) {}
    return 0;
  }

  // =============================
  // واجبات الطالب
  // =============================

  /// جلب قائمة واجبات الطالب
  Future<Map<String, dynamic>> fetchStudentAssignments({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        "/student/assignments",
        queryParameters: {"page": page, "limit": limit},
      );
      if ((response.statusCode == 200) && (response.data["success"] == true)) {
        // يرجع: data: [...], pagination: {page, limit, total}
        return Map<String, dynamic>.from(response.data);
      }
      throw Exception(response.data["message"] ?? "فشل تحميل الواجبات");
    } catch (e) {
      throw Exception("❌ خطأ أثناء تحميل الواجبات: $e");
    }
  }

  /// جلب تفاصيل واجب
  Future<Map<String, dynamic>> fetchAssignmentById(String assignmentId) async {
    try {
      final response = await _dio.get("/student/assignments/$assignmentId");
      if ((response.statusCode == 200) && (response.data["success"] == true)) {
        return Map<String, dynamic>.from(response.data);
      }
      throw Exception(response.data["message"] ?? "فشل تحميل تفاصيل الواجب");
    } on DioException catch (e) {
      final res = e.response;
      if (res != null) {
        final data = res.data is Map<String, dynamic>
            ? res.data as Map<String, dynamic>
            : <String, dynamic>{};
        final serverMsg = (data["message"] ?? "فشل تحميل تفاصيل الواجب").toString();
        // أعِد رسالة الخادم مباشرة لتُعرض للمستخدم (مثل: هذا الواجب غير متوفر لك)
        throw Exception(serverMsg);
      }
      throw Exception("❌ خطأ أثناء تحميل تفاصيل الواجب: ${e.message}");
    } catch (e) {
      throw Exception("❌ خطأ أثناء تحميل تفاصيل الواجب: $e");
    }
  }

  /// إرسال/تحديث تسليم واجب
  Future<Map<String, dynamic>> submitAssignment({
    required String assignmentId,
    String? contentText,
    String? linkUrl,
    List<dynamic>? attachments,
    String status = 'submitted',
  }) async {
    try {
      final response = await _dio.post(
        "/student/assignments/$assignmentId/submit",
        data: {
          "content_text": contentText,
          "link_url": linkUrl,
          "attachments": attachments ?? [],
          "status": status,
        },
      );
      if ((response.statusCode == 200) && (response.data["success"] == true)) {
        return Map<String, dynamic>.from(response.data);
      }
      throw Exception(response.data["message"] ?? "فشل إرسال التسليم");
    } catch (e) {
      throw Exception("❌ خطأ أثناء إرسال التسليم: $e");
    }
  }

  // =============================
  // حجوزات الطالب (الكورسات)
  // =============================

  /// إنشاء حجز أولي لدورة
  Future<Map<String, dynamic>> createCourseBooking({
    required String courseId,
    required String studentMessage,
  }) async {
    try {
      final response = await _dio.post(
        "/student/bookings",
        data: {"courseId": courseId, "studentMessage": studentMessage},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Map<String, dynamic>.from(response.data);
      }
      throw Exception(response.data["message"] ?? "فشل إنشاء الحجز");
    } catch (e) {
      throw Exception("❌ خطأ أثناء إنشاء الحجز: $e");
    }
  }

  /// جلب قائمة حجوزات الطالب
  Future<Map<String, dynamic>> fetchStudentBookings({
    String? studyYear,
    int page = 1,
    int limit = 10,
    String? status, // pending, approved, rejected, canceled
  }) async {
    try {
      final qp = {
        "page": page,
        "limit": limit,
        if (studyYear != null) "studyYear": studyYear,
        if (status != null && status.isNotEmpty) "status": status,
      };
      final response = await _dio.get("/student/bookings", queryParameters: qp);
      if (response.statusCode == 200) {
        print(response.data);
        return Map<String, dynamic>.from(response.data);
      }
      throw Exception(response.data["message"] ?? "فشل تحميل الحجوزات");
    } catch (e) {
      throw Exception("❌ خطأ أثناء تحميل الحجوزات: $e");
    }
  }

  /// جلب تفاصيل حجز واحد
  Future<Map<String, dynamic>> fetchBookingDetails(String bookingId) async {
    try {
      final response = await _dio.get("/student/bookings/$bookingId");
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      }
      throw Exception(response.data["message"] ?? "فشل تحميل تفاصيل الحجز");
    } catch (e) {
      throw Exception("❌ خطأ أثناء تحميل تفاصيل الحجز: $e");
    }
  }

  /// إحصائيات الحجوزات
  Future<Map<String, dynamic>> fetchBookingsStatsSummary({
    String? studyYear,
  }) async {
    try {
      final response = await _dio.get(
        "/student/bookings/stats/summary",
        queryParameters: {if (studyYear != null) "studyYear": studyYear},
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      }
      throw Exception(
        response.data["message"] ?? "فشل تحميل إحصائيات الحجوزات",
      );
    } catch (e) {
      throw Exception("❌ خطأ أثناء تحميل الإحصائيات: $e");
    }
  }

  /// إلغاء حجز
  Future<void> cancelBooking({
    required String bookingId,
    required String reason,
  }) async {
    try {
      final response = await _dio.patch(
        "/student/bookings/$bookingId/cancel",
        data: {"reason": reason},
      );
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception(response.data["message"] ?? "فشل إلغاء الحجز");
      }
    } catch (e) {
      throw Exception("❌ خطأ أثناء إلغاء الحجز: $e");
    }
  }

  /// إعادة تفعيل/إرسال طلب الحجز
  Future<Map<String, dynamic>> reactivateBooking(String bookingId) async {
    try {
      final response = await _dio.patch(
        "/student/bookings/$bookingId/reactivate",
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      }
      // في حال لم تكن 200 اعتبرها فشل وحاول استخراج الرسائل
      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : <String, dynamic>{};
      final msg = (data["message"] ?? "فشل إعادة تفعيل الحجز").toString();
      final errors =
          (data["errors"] is List && (data["errors"] as List).isNotEmpty)
          ? (data["errors"] as List).join("، ")
          : null;
      final suggestion = data["suggestion"]?.toString();
      final composed = [
        msg,
        if (errors != null) errors,
        if (suggestion != null) suggestion,
      ].where((e) => e.toString().trim().isNotEmpty).join(" | ");
      throw Exception(composed);
    } on DioException catch (e) {
      final res = e.response;
      if (res != null) {
        final data = res.data is Map<String, dynamic>
            ? res.data as Map<String, dynamic>
            : <String, dynamic>{};
        final msg = (data["message"] ?? "فشل إعادة تفعيل الحجز").toString();
        final errors =
            (data["errors"] is List && (data["errors"] as List).isNotEmpty)
            ? (data["errors"] as List).join("، ")
            : null;
        final suggestion = data["suggestion"]?.toString();
        final composed = [
          msg,
          if (errors != null) errors,
          if (suggestion != null) suggestion,
        ].where((e) => e.toString().trim().isNotEmpty).join(" | ");
        throw Exception(composed);
      }
      throw Exception("❌ خطأ أثناء إعادة تفعيل الحجز: ${e.message}");
    } catch (e) {
      throw Exception("❌ خطأ أثناء إعادة تفعيل الحجز: $e");
    }
  }

  Future<Map<String, dynamic>> checkInAttendance({
    required String teacherId,
  }) async {
    try {
      final response = await _dio.post(
        "/student/attendance/check-in",
        data: {"teacherId": teacherId},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Map<String, dynamic>.from(response.data);
      }

      // ✅ لو السيرفر رجّع رسالة خطأ، نرميها
      final serverMsg =
          (response.data is Map && response.data["message"] != null)
          ? response.data["message"].toString()
          : "فشل تسجيل الحضور";
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: serverMsg,
      );
    } on DioException catch (e) {
      // ✅ هنا نمرر الرسالة القادمة من السيرفر
      final data = e.response?.data;
      final serverMsg = (data is Map && data['message'] != null)
          ? data['message'].toString()
          : null;
      throw Exception(serverMsg ?? "فشل تسجيل الحضور");
    } catch (e) {
      throw Exception("❌ خطأ غير متوقع: $e");
    }
  }

  Future<List<Map<String, dynamic>>> fetchWeeklyScheduleByCourse(
    String courseId,
  ) async {
    try {
      final response = await _dio.get(
        "/student/enrollments/schedule/weekly/by-course/$courseId",
      );
      if (response.statusCode == 200 && response.data["success"] == true) {
        final list = response.data["data"] as List;
        return List<Map<String, dynamic>>.from(list);
      } else {
        throw Exception(response.data["message"] ?? "فشل تحميل جدول الأسبوع");
      }
    } catch (e) {
      throw Exception("❌ خطأ أثناء تحميل جدول الأسبوع: $e");
    }
  }

  /// ✅ جلب سجل الحضور/الغياب/الإجازات للطالب لكورس معيّن
  Future<Map<String, dynamic>> fetchMyAttendanceByCourse(String courseId) async {
    try {
      final response = await _dio.get(
        "/student/attendance/by-course/$courseId",
      );
      if (response.statusCode == 200 && response.data["success"] == true) {
        // نتوقع أن يكون تحت المفتاح data
        final data = response.data["data"];
        if (data is Map<String, dynamic>) {
          return Map<String, dynamic>.from(data);
        }
        return {"items": data};
      } else {
        throw Exception(
          response.data["message"] ?? "فشل تحميل سجل الحضور",
        );
      }
    } catch (e) {
      throw Exception("❌ خطأ أثناء تحميل سجل الحضور: $e");
    }
  }
}
