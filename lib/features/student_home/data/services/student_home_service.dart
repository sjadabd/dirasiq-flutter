import 'package:mulhimiq/core/services/api_service.dart';

/// Thin data-source for the Student Home screen.
///
/// Today the screen is composed client-side from several existing student
/// endpoints (see methods below). Each call returns the raw decoded payload;
/// mapping to models happens in [StudentHomeRepository].
///
/// ── BACKEND TODO — single optimised endpoint ────────────────────────────────
/// The ideal shape is one round-trip:
///
///   GET /api/student/home
///
/// returning an envelope where every section is present as an array or null so
/// the client can render conditionally without N requests:
///
///   {
///     "success": true,
///     "data": {
///       "profile":              { id, name, profileImagePath, grade },
///       "upcomingLecture":      { courseName, teacher, nextOccurrence, type, joinUrl } | null,
///       "upcomingExam":         { title, courseName, examDate } | null,
///       "progress":             { progressPercent, attendancePercent,
///                                 assignmentsPercent, examsPercent } | null,
///       "weeklySchedule":       { scheduleByDay: { "1": [...], ... } },
///       "myTeachers":           [ { teacher, courses[] } ],
///       "myVideoCourses":       [ { id, title, teacher, thumbnail, progress } ],
///       "news":                 [ { id, title, image, createdAt } ],
///       "recommendedTeachers":  [ ... ],
///       "recommendedCourses":   [ ... ],          // physical / in-person
///       "recommendedVideoCourses": [ ... ]
///     }
///   }
///
/// When that endpoint ships, replace the parallel fan-out in the repository
/// with a single [fetchHomeAggregate] call.
///
/// Endpoints currently in use:
///   GET /api/student/dashboard/overview          → upcoming lecture/exam + progress
///   GET /api/student/dashboard/weekly-schedule    → weekly schedule
///   GET /api/student/enrollments                  → my teachers (grouped client-side)
///   GET /api/student/video-courses/my-library     → my video courses
///   GET /api/news?newsType=mobile                 → latest news
///   GET /api/student/teachers/suggested           → recommended teachers
///   GET /api/student/courses/suggested            → recommended physical courses
///   GET /api/student/video-marketplace            → recommended video courses
class StudentHomeService {
  StudentHomeService({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  /// NOT YET AVAILABLE. See class docs — the backend should expose
  /// `GET /api/student/home`. Kept as the seam the repository will switch to.
  // ignore: unused_element
  Future<Map<String, dynamic>> fetchHomeAggregate() {
    throw UnimplementedError(
      'GET /api/student/home is not implemented on the backend yet. '
      'The repository composes the home from per-section endpoints instead.',
    );
  }

  Future<Map<String, dynamic>> overview() => _api.fetchStudentDashboardOverview();

  Future<Map<String, dynamic>> weeklySchedule() => _api.fetchStudentWeeklySchedule();

  Future<Map<String, dynamic>> enrollments() => _api.fetchStudentEnrollments();

  Future<Map<String, dynamic>> myVideoLibrary() => _api.fetchMyVideoLibrary();

  Future<List<Map<String, dynamic>>> contentFeed() => _api.fetchContentFeed(limit: 8);

  Future<Map<String, dynamic>> suggestedTeachers() => _api.fetchSuggestedTeachers();

  Future<List<Map<String, dynamic>>> suggestedCourses() =>
      _api.fetchSuggestedCourses(maxDistance: 50);

  Future<Map<String, dynamic>> videoMarketplace() => _api.fetchVideoMarketplace();
}
