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
  // "Other courses by this teacher" — discovery surface for live + video
  // courses the same teacher offers that are NOT this course. Lets the
  // student keep exploring the teacher's catalog without leaving the hub.
  otherTeacherCourses,
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

  /// Finished or soft-deleted course → student sees archive-only hub.
  bool get isArchiveMode {
    final course = _overviewCourse;
    if (course == null) return false;
    return _truthy(course['is_archived']) ||
        _truthy(course['is_ended']) ||
        _truthy(course['is_deleted']) ||
        _truthy(course['isDeleted']) ||
        _endDatePassed(course['end_date'] ?? course['endDate']);
  }

  bool get isCourseDeleted {
    final course = _overviewCourse;
    if (course == null) return false;
    return _truthy(course['is_deleted']) || _truthy(course['isDeleted']);
  }

  bool get isCourseEnded {
    final course = _overviewCourse;
    if (course == null) return false;
    return _truthy(course['is_ended']) ||
        _endDatePassed(course['end_date'] ?? course['endDate']);
  }

  Map<String, dynamic>? get _overviewCourse {
    final ov = overview.value;
    if (ov == null) return null;
    if (ov['course'] is Map) {
      return Map<String, dynamic>.from(ov['course'] as Map);
    }
    return ov;
  }

  static bool _truthy(dynamic v) =>
      v == true || v == 1 || v?.toString().toLowerCase() == 'true';

  static bool _endDatePassed(dynamic raw) {
    final end = DateTime.tryParse('${raw ?? ''}');
    if (end == null) return false;
    final today = DateTime.now();
    final endDay = DateTime(end.year, end.month, end.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    return endDay.isBefore(todayDay);
  }

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

  // Other teacher courses — the same teacher's OTHER live courses + the
  // teacher's video catalog (free + paid), so the student can keep
  // discovering without leaving the hub. Loaded only when teacherId was
  // supplied at construction time (an enrolled row always carries it).
  // Two reactive lists so the section widget can render two carousels
  // without re-filtering on every rebuild.
  final otherLiveCourses = <Map<String, dynamic>>[].obs;
  final otherVideoCourses = <Map<String, dynamic>>[].obs;
  final otherTeacherCoursesLoading = false.obs;
  final otherTeacherCoursesError = ''.obs;

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
      case CourseHubSection.otherTeacherCourses:
        if ((otherLiveCourses.isNotEmpty || otherVideoCourses.isNotEmpty) ||
            otherTeacherCoursesLoading.value) {
          return;
        }
        return _loadOtherTeacherCourses();
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
    if (otherLiveCourses.isNotEmpty || otherVideoCourses.isNotEmpty) {
      otherLiveCourses.clear();
      otherVideoCourses.clear();
      futures.add(_loadOtherTeacherCourses());
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
        limit: 10,
      );
      // API envelope: data: { invoices, report, page, limit }
      final data = res['data'];
      final rawList = data is Map
          ? (data['invoices'] ?? data['items'] ?? data['data'])
          : data;
      final list = _safeList(rawList);
      invoices.assignAll(
        list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
      );
    } catch (e) {
      invoicesError.value = 'تعذّر تحميل الفواتير';
    } finally {
      invoicesLoading.value = false;
    }
  }

  /// Loads the same teacher's OTHER live courses + their video catalog,
  /// in parallel. Returns early if the teacherId wasn't supplied (we have
  /// no way to ask "what else does this teacher offer?" without it).
  ///
  /// Defensive on both endpoints: if either one fails, we still populate
  /// whatever came back successfully and only error out when both fail
  /// — partial discovery is better than none.
  Future<void> _loadOtherTeacherCourses() async {
    final tid = teacherId;
    if (tid == null || tid.isEmpty) {
      // Nothing to discover without a teacher id. Mark "loaded" with
      // empty lists so the section silently collapses.
      otherTeacherCoursesLoading.value = false;
      return;
    }
    otherTeacherCoursesLoading.value = true;
    otherTeacherCoursesError.value = '';
    try {
      final results = await Future.wait([
        _api
            .fetchTeacherSubjectsCourses(tid)
            .catchError((_) => <String, dynamic>{}),
        _api
            .fetchVideoMarketplace(teacherId: tid)
            .catchError((_) => <String, dynamic>{}),
      ]);

      // Live courses — exclude THIS course so the hub never lists itself
      // in its own "other courses" rail.
      final liveRaw = results[0];
      final liveList = (liveRaw['courses'] is List)
          ? List<Map<String, dynamic>>.from(
              (liveRaw['courses'] as List)
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e)),
            )
          : <Map<String, dynamic>>[];
      otherLiveCourses.assignAll(
        liveList.where((c) => (c['id'] ?? '').toString() != courseId),
      );

      // Video marketplace — the backend already returns the teacher's
      // approved catalog with isFree / price flags. We render free + paid
      // distinctly in the section widget.
      final vodRaw = results[1];
      final vodData = vodRaw['data'];
      final vodList = (vodData is List)
          ? List<Map<String, dynamic>>.from(
              vodData
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e)),
            )
          : <Map<String, dynamic>>[];
      otherVideoCourses.assignAll(vodList);
    } catch (_) {
      // Partial failure already swallowed by per-future catchError; this
      // catch only fires on an unexpected throw (e.g. Future.wait itself).
      otherTeacherCoursesError.value = 'تعذّر تحميل دورات الأستاذ الأخرى';
    } finally {
      otherTeacherCoursesLoading.value = false;
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
