// Phase 6 — Course Hub (National Video Marketplace).
//
// One GetX controller that owns ALL per-section state for the unified
// Course Hub screen. Each section is loaded lazily on first request via
// `ensureSectionLoaded(...)`; re-entering the screen never re-fetches a
// section that's already populated.
//
// The controller intentionally stores RAW backend payloads (List/Map
// shapes from ApiService) and lets each section widget pick what it
// needs. This keeps the controller wire-shape-agnostic and easy to
// extend when later phases add more data per section.

import 'package:get/get.dart';
import 'package:mulhimiq/core/services/api_service.dart';

enum CourseHubSection {
  overview,
  announcements,
  academic,
  attendance,
  schedule,
  materials,
  videos,
  billing,
}

class CourseHubController extends GetxController {
  CourseHubController({
    required this.courseId,
    this.initialCourseName,
    this.teacherId,
  });

  final ApiService _api = ApiService();

  /// Live course id — required entry point for every section fetch.
  final String courseId;

  /// Best-effort name shown in the app bar while the overview is
  /// loading. Replaced by `overview.value['course']?['name']` once the
  /// overview fetch completes.
  final String? initialCourseName;

  /// Teacher id, when known (handed in from the caller — e.g. from the
  /// enrollments row or the teacher picker). Surfaced in the Overview
  /// section for "open teacher details" quick action.
  final String? teacherId;

  // ---------------------------------------------------------------------------
  // Per-section state
  //
  // Pattern: each section has (data, loading, error) reactive triplets.
  // The widget pulls from these; the controller writes into them inside
  // `ensureSectionLoaded`.
  // ---------------------------------------------------------------------------

  // Overview — full course details (teacher, dates, images, price, ...).
  final overview = Rxn<Map<String, dynamic>>();
  final overviewLoading = false.obs;
  final overviewError = ''.obs;

  // Academic — counts of pending assignments + upcoming exams. We fetch
  // the first page of each list and read the meta.pagination.total so
  // the section card shows a number without paginating client-side.
  final academic = Rxn<_AcademicSummary>();
  final academicLoading = false.obs;
  final academicError = ''.obs;

  // Attendance — by-course log returned by the existing endpoint. The
  // widget renders a summary (present / absent counts) + a "view full
  // log" button.
  final attendance = Rxn<Map<String, dynamic>>();
  final attendanceLoading = false.obs;
  final attendanceError = ''.obs;

  // Schedule — list of weekly slots for THIS course.
  final scheduleRows = <Map<String, dynamic>>[].obs;
  final scheduleLoading = false.obs;
  final scheduleError = ''.obs;

  // Videos — video courses pinned to this live course AND viewable by
  // the student (Phase 2 access function). Empty list = "nothing here
  // yet".
  final videos = <Map<String, dynamic>>[].obs;
  final videosLoading = false.obs;
  final videosError = ''.obs;

  // Billing — first page of invoices filtered to this course (limit=5
  // is enough to render the section summary).
  final invoices = <Map<String, dynamic>>[].obs;
  final invoicesLoading = false.obs;
  final invoicesError = ''.obs;

  // ---------------------------------------------------------------------------
  // Lazy loader — single entry point for every section.
  //
  // Returns immediately if the section is already loaded OR currently
  // loading. Errors are stored on the section's error Rx string; the
  // widget decides how to surface them (inline red banner, retry button,
  // etc.).
  // ---------------------------------------------------------------------------

  Future<void> ensureSectionLoaded(CourseHubSection section) async {
    switch (section) {
      case CourseHubSection.overview:
        if (overview.value != null || overviewLoading.value) return;
        return _loadOverview();
      case CourseHubSection.academic:
        if (academic.value != null || academicLoading.value) return;
        return _loadAcademic();
      case CourseHubSection.attendance:
        if (attendance.value != null || attendanceLoading.value) return;
        return _loadAttendance();
      case CourseHubSection.schedule:
        if (scheduleRows.isNotEmpty || scheduleLoading.value) return;
        return _loadSchedule();
      case CourseHubSection.videos:
        if (videos.isNotEmpty || videosLoading.value) return;
        return _loadVideos();
      case CourseHubSection.billing:
        if (invoices.isNotEmpty || invoicesLoading.value) return;
        return _loadBilling();
      case CourseHubSection.announcements:
      case CourseHubSection.materials:
        // Phase 6 does not own a per-course fetch for these — the
        // section widgets render static "open notifications / contact
        // teacher" CTAs. A future phase wires per-course filters.
        return;
    }
  }

  /// Pull-to-refresh — clears every section that has already loaded
  /// data and re-fetches the ones that were populated. Sections that
  /// have not been opened yet stay in their initial "not yet loaded"
  /// state so we don't spend bandwidth on collapsed sections.
  Future<void> refreshAll() async {
    final futures = <Future<void>>[];

    if (overview.value != null) {
      overview.value = null;
      futures.add(_loadOverview());
    }
    if (academic.value != null) {
      academic.value = null;
      futures.add(_loadAcademic());
    }
    if (attendance.value != null) {
      attendance.value = null;
      futures.add(_loadAttendance());
    }
    if (scheduleRows.isNotEmpty) {
      scheduleRows.clear();
      futures.add(_loadSchedule());
    }
    if (videos.isNotEmpty) {
      videos.clear();
      futures.add(_loadVideos());
    }
    if (invoices.isNotEmpty) {
      invoices.clear();
      futures.add(_loadBilling());
    }

    await Future.wait(futures);
  }

  // ---------------------------------------------------------------------------
  // Section fetches
  // ---------------------------------------------------------------------------

  Future<void> _loadOverview() async {
    overviewLoading.value = true;
    overviewError.value = '';
    try {
      final res = await _api.fetchCourseDetails(courseId);
      final data = res['data'];
      if (data is Map) {
        overview.value = Map<String, dynamic>.from(data);
      } else {
        overview.value = res;
      }
    } catch (e) {
      overviewError.value = 'تعذّر تحميل بيانات الدورة';
    } finally {
      overviewLoading.value = false;
    }
  }

  Future<void> _loadAcademic() async {
    academicLoading.value = true;
    academicError.value = '';
    try {
      // Two parallel fetches — assignments + exams. We only want the
      // count + the next-due item (if any), so limit=1 is enough.
      final results = await Future.wait([
        _api
            .fetchStudentAssignments(page: 1, limit: 5)
            .catchError((_) => <String, dynamic>{}),
        _api
            .fetchStudentExams(type: 'daily', page: 1, limit: 5)
            .catchError((_) => <String, dynamic>{}),
      ]);

      final assignmentsRes = results[0];
      final examsRes = results[1];

      final assignmentsList = _safeList(assignmentsRes['data']);
      final examsList = _safeList(examsRes['data']);
      final assignmentsTotal = _safeTotal(assignmentsRes);
      final examsTotal = _safeTotal(examsRes);

      academic.value = _AcademicSummary(
        assignmentsCount: assignmentsTotal,
        upcomingExamsCount: examsTotal,
        latestAssignment: assignmentsList.isNotEmpty
            ? Map<String, dynamic>.from(assignmentsList.first as Map)
            : null,
        latestExam: examsList.isNotEmpty
            ? Map<String, dynamic>.from(examsList.first as Map)
            : null,
      );
    } catch (e) {
      academicError.value = 'تعذّر تحميل الأقسام الأكاديمية';
    } finally {
      academicLoading.value = false;
    }
  }

  Future<void> _loadAttendance() async {
    attendanceLoading.value = true;
    attendanceError.value = '';
    try {
      final res = await _api.fetchMyAttendanceByCourse(courseId);
      final data = res['data'];
      if (data is Map) {
        attendance.value = Map<String, dynamic>.from(data);
      } else {
        attendance.value = res;
      }
    } catch (e) {
      attendanceError.value = 'تعذّر تحميل سجل الحضور';
    } finally {
      attendanceLoading.value = false;
    }
  }

  Future<void> _loadSchedule() async {
    scheduleLoading.value = true;
    scheduleError.value = '';
    try {
      final list = await _api.fetchWeeklyScheduleByCourse(courseId);
      scheduleRows.assignAll(list);
    } catch (e) {
      scheduleError.value = 'تعذّر تحميل جدول الأسبوع';
    } finally {
      scheduleLoading.value = false;
    }
  }

  Future<void> _loadVideos() async {
    videosLoading.value = true;
    videosError.value = '';
    try {
      final res = await _api.fetchVideoCoursesForCourse(courseId, limit: 12);
      final list = _safeList(res['data']);
      videos.assignAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
    } catch (e) {
      videosError.value = 'تعذّر تحميل الكورسات المرئية';
    } finally {
      videosLoading.value = false;
    }
  }

  Future<void> _loadBilling() async {
    invoicesLoading.value = true;
    invoicesError.value = '';
    try {
      final res = await _api.fetchStudentInvoices(
        courseId: courseId,
        page: 1,
        limit: 5,
      );
      final list = _safeList(res['data']);
      invoices.assignAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
    } catch (e) {
      invoicesError.value = 'تعذّر تحميل الفواتير';
    } finally {
      invoicesLoading.value = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<dynamic> _safeList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is Map && raw['items'] is List) return raw['items'] as List;
    return const [];
  }

  int _safeTotal(Map<String, dynamic> res) {
    // The Phase 1 envelope puts pagination meta under `meta.pagination`.
    final meta = res['meta'];
    if (meta is Map) {
      final pag = meta['pagination'];
      if (pag is Map) {
        final t = pag['total'];
        if (t is num) return t.toInt();
      }
    }
    // Fall back to the array length when no meta is present.
    final data = res['data'];
    if (data is List) return data.length;
    return 0;
  }
}

class _AcademicSummary {
  _AcademicSummary({
    required this.assignmentsCount,
    required this.upcomingExamsCount,
    this.latestAssignment,
    this.latestExam,
  });

  final int assignmentsCount;
  final int upcomingExamsCount;
  final Map<String, dynamic>? latestAssignment;
  final Map<String, dynamic>? latestExam;
}

/// Public read accessor for the academic summary's inferred shape. Lets
/// the section widget pattern-match `controller.academic.value!` without
/// having to import the private `_AcademicSummary` class.
extension AcademicSummaryAccess on CourseHubController {
  int get assignmentsCount => academic.value?.assignmentsCount ?? 0;
  int get upcomingExamsCount => academic.value?.upcomingExamsCount ?? 0;
  Map<String, dynamic>? get latestAssignment => academic.value?.latestAssignment;
  Map<String, dynamic>? get latestExam => academic.value?.latestExam;
}
