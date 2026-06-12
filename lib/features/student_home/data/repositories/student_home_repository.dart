import 'package:mulhimiq/core/services/auth_service.dart';

import '../models/student_home_data.dart';
import '../services/student_home_service.dart';

/// One settled fetch: its [value] (null on failure) and whether it [ok]-succeeded.
class _Outcome {
  const _Outcome(this.value, this.ok);
  final Object? value;
  final bool ok;
}

/// Repository result: the composed [data] plus a reliability signal — how many
/// of the four CRITICAL endpoints (dashboard overview, weekly schedule,
/// enrollments, video-courses library) actually succeeded. The controller uses
/// this to distinguish a *confirmed* new student from a network failure that
/// merely *looks* empty.
class StudentHomeResult {
  const StudentHomeResult({
    required this.data,
    required this.criticalSuccess,
    required this.criticalTotal,
  });

  final StudentHomeData data;
  final int criticalSuccess;
  final int criticalTotal;

  /// Every critical endpoint succeeded → an empty result can be trusted as a
  /// genuinely new student.
  bool get allCriticalOk => criticalSuccess == criticalTotal;

  /// At least one critical endpoint succeeded → there is real data to render
  /// (or a non-empty section to trust). Zero means a total failure.
  bool get anyCriticalOk => criticalSuccess > 0;
}

/// Composes [StudentHomeResult] from the per-section endpoints.
///
/// Each source is awaited in parallel and isolated: a single failing section
/// degrades to empty/null instead of failing the whole screen (partial-failure
/// resilience). The four CRITICAL endpoints additionally report success/failure
/// so the caller can tell "genuinely new student" from "couldn't load" — see
/// [StudentHomeResult].
class StudentHomeRepository {
  StudentHomeRepository({StudentHomeService? service, AuthService? auth})
      : _service = service ?? StudentHomeService(),
        _auth = auth ?? AuthService();

  final StudentHomeService _service;
  final AuthService _auth;

  Future<StudentHomeResult> load() async {
    // BACKEND TODO: collapse this fan-out into a single
    // `await _service.fetchHomeAggregate()` once GET /api/student/home exists.
    //
    // Index 0 (profile) is local and non-critical. Indices 1–4 are the CRITICAL
    // endpoints whose success determines new-vs-active; 5–8 are best-effort.
    final outcomes = await Future.wait<_Outcome>([
      _call(_auth.getUser()),              // 0 — profile (local, non-critical)
      _call(_service.overview()),          // 1 — CRITICAL: progress + upcoming
      _call(_service.weeklySchedule()),    // 2 — CRITICAL: weekly schedule
      _call(_service.enrollments()),       // 3 — CRITICAL: my teachers
      _call(_service.myVideoLibrary()),    // 4 — CRITICAL: my video courses
      _call(_service.latestNews()),        // 5
      _call(_service.suggestedTeachers()), // 6
      _call(_service.suggestedCourses()),  // 7
      _call(_service.videoMarketplace()),  // 8
    ]);

    final user = outcomes[0].value as Map<String, dynamic>?;
    final overview = _asMap(_unwrapData(outcomes[1].value));
    final schedule = _asMap(_unwrapData(outcomes[2].value));
    final enrollments = outcomes[3].value;
    final videoLib = outcomes[4].value;
    final news = outcomes[5].value;
    final sgTeachers = outcomes[6].value;
    final sgCourses = outcomes[7].value;
    final marketplace = outcomes[8].value;

    final criticalOk = [
      outcomes[1].ok, // overview
      outcomes[2].ok, // weekly schedule
      outcomes[3].ok, // enrollments
      outcomes[4].ok, // video library
    ];

    final myTeachers = _parseTeachers(enrollments);
    // Don't recommend a teacher the student is already enrolled with.
    final myTeacherIds =
        myTeachers.map((t) => t.id).where((id) => id.isNotEmpty).toSet();
    final recommendedTeachers = _parseRecommendedTeachers(sgTeachers)
        .where((t) => !myTeacherIds.contains(t.id))
        .toList();

    final data = StudentHomeData(
      profile: StudentProfile.fromUser(user),
      upcomingLecture: UpcomingLecture.fromOverview(overview['nextSession']),
      upcomingExam: UpcomingExam.fromOverview(overview['nextMonthlyExam'] ?? overview['nextExam']),
      progress: overview.isEmpty ? null : AcademicProgress.fromOverview(overview),
      streakDays: (overview['streakDays'] ?? overview['streak_days']) is num
          ? (overview['streakDays'] ?? overview['streak_days']).round()
          : null,
      weeklySchedule: _parseSchedule(schedule),
      myTeachers: myTeachers,
      myVideoCourses: _parseVideoList(videoLib, ['items', 'courses', 'library', 'videoCourses']),
      news: _parseNews(news),
      recommendedTeachers: recommendedTeachers,
      recommendedCourses: _parseRecommendedCourses(sgCourses),
      recommendedVideoCourses: _parseMarketplaceRecommended(marketplace),
    );

    return StudentHomeResult(
      data: data,
      criticalSuccess: criticalOk.where((ok) => ok).length,
      criticalTotal: criticalOk.length,
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  /// Settles a fetch into an [_Outcome] — captures both the value and whether
  /// the call succeeded, so critical-endpoint reliability can be tracked.
  Future<_Outcome> _call(Future<Object?> f) async {
    try {
      return _Outcome(await f, true);
    } catch (_) {
      return const _Outcome(null, false);
    }
  }

  Map<String, dynamic> _asMap(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  /// Some endpoints return `{ success, data: {...} }`, others return the data
  /// directly. Prefer the nested `data` when present.
  Object? _unwrapData(Object? v) {
    if (v is Map && v['data'] != null) return v['data'];
    return v;
  }

  List<Map<String, dynamic>> _listOf(Object? v) {
    if (v is List) {
      return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return const [];
  }

  List<Map<String, dynamic>> _extractList(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      if (m[k] is List) return _listOf(m[k]);
    }
    return const [];
  }

  List<WeeklyScheduleDay> _parseSchedule(Map<String, dynamic> schedule) {
    final byDay = schedule['scheduleByDay'];
    if (byDay is! Map) return const [];
    final days = <WeeklyScheduleDay>[];
    byDay.forEach((key, value) {
      final weekday = int.tryParse(key.toString()) ?? 0;
      final lessons = _listOf(value).map(ScheduleLesson.fromJson).toList();
      days.add(WeeklyScheduleDay(weekday: weekday, lessons: lessons));
    });
    days.sort((a, b) => a.weekday.compareTo(b.weekday));
    return days;
  }

  List<MyTeacher> _parseTeachers(Object? raw) {
    final data = _unwrapData(raw);
    final enrollments = _listOf(data);
    final groups = <String, MyTeacher>{};
    for (final e in enrollments) {
      final t = e['teacher'] is Map ? Map<String, dynamic>.from(e['teacher']) : <String, dynamic>{};
      final id = t['id']?.toString();
      if (id == null || id.isEmpty) continue;
      final c = e['course'] is Map ? Map<String, dynamic>.from(e['course']) : <String, dynamic>{};
      groups.putIfAbsent(
        id,
        () => MyTeacher(
          id: id,
          name: (t['name'] ?? '').toString(),
          imageUrl: resolveAssetUrl(t['profileImagePath'] ?? t['profile_image_path'] ?? t['avatar']),
          courses: [],
        ),
      );
      groups[id]!.courses.add(TeacherCourseRef(
        id: (c['id'] ?? '').toString(),
        name: (c['name'] ?? '').toString(),
        bookingId: (e['bookingId'] ?? e['booking_id'] ?? '').toString(),
        status: (e['status'] ?? '').toString(),
      ));
    }
    return groups.values.toList();
  }

  List<VideoCourseItem> _parseVideoList(Object? raw, List<String> mapKeys) {
    final data = _unwrapData(raw);
    if (data is List) return _listOf(data).map(VideoCourseItem.fromJson).toList();
    if (data is Map) {
      return _extractList(Map<String, dynamic>.from(data), mapKeys)
          .map(VideoCourseItem.fromJson)
          .toList();
    }
    return const [];
  }

  List<NewsItem> _parseNews(Object? raw) {
    if (raw is List) return _listOf(raw).map(NewsItem.fromJson).toList();
    final data = _unwrapData(raw);
    return _listOf(data).map(NewsItem.fromJson).toList();
  }

  List<RecommendedTeacher> _parseRecommendedTeachers(Object? raw) {
    final data = _unwrapData(raw);
    List<Map<String, dynamic>> list;
    if (data is Map) {
      list = _extractList(Map<String, dynamic>.from(data), ['items', 'teachers', 'data']);
    } else {
      list = _listOf(data);
    }
    return list.map(RecommendedTeacher.fromJson).toList();
  }

  List<RecommendedCourse> _parseRecommendedCourses(Object? raw) {
    final data = _unwrapData(raw);
    final list = data is List ? _listOf(data) : _extractList(_asMap(data), ['courses', 'items', 'data']);
    return list.map(RecommendedCourse.fromJson).toList();
  }

  List<VideoCourseItem> _parseMarketplaceRecommended(Object? raw) {
    final body = _asMap(_unwrapData(raw));
    if (body.isEmpty) return const [];
    // Prefer the curated "recommended" section, fall back to newest/trending.
    for (final key in const ['recommended', 'forYou', 'newest', 'latest', 'trending', 'popular']) {
      if (body[key] is List && (body[key] as List).isNotEmpty) {
        return _listOf(body[key]).map(VideoCourseItem.fromJson).toList();
      }
    }
    return const [];
  }
}
