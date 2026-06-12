import 'package:mulhimiq/core/config/app_config.dart';

/// Models for the Student Home screen.
///
/// Every `fromJson` is defensive: the backend response envelope drifts
/// (snake_case vs camelCase, `id` vs `_id`, `course_name` vs `name`), so each
/// field probes the known spellings. This is the documented project smell —
/// the long-term fix is a single normalised `GET /api/student/home` envelope
/// (see [StudentHomeService]).

/// Resolves a possibly-relative asset path to an absolute URL using the
/// configured server origin. Returns empty string for null/blank input.
String resolveAssetUrl(Object? path) {
  final p = path?.toString().trim() ?? '';
  if (p.isEmpty) return '';
  if (p.startsWith('http://') || p.startsWith('https://') || p.startsWith('data:')) {
    return p;
  }
  final base = AppConfig.serverBaseUrl.replaceAll(RegExp(r'/$'), '');
  return p.startsWith('/') ? '$base$p' : '$base/$p';
}

T? _firstOf<T>(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v != null) return v as T;
  }
  return null;
}

String _str(Map<String, dynamic> m, List<String> keys) =>
    _firstOf<Object>(m, keys)?.toString().trim() ?? '';

int? _intOrNull(Object? v) {
  if (v == null) return null;
  if (v is num) return v.round();
  return int.tryParse(v.toString());
}

DateTime? _date(Object? v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

/// How an upcoming/scheduled lecture is delivered.
enum LectureType { physical, live, video }

LectureType lectureTypeFrom(Object? raw) {
  final s = raw?.toString().toLowerCase() ?? '';
  if (s.contains('live') || s.contains('بث') || s.contains('مباشر')) {
    return LectureType.live;
  }
  if (s.contains('video') || s.contains('vod') || s.contains('مرئي') || s.contains('فيديو')) {
    return LectureType.video;
  }
  return LectureType.physical;
}

class StudentProfile {
  const StudentProfile({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.gradeName,
  });

  final String id;
  final String name;
  final String imageUrl;
  final String? gradeName;

  factory StudentProfile.fromUser(Map<String, dynamic>? user) {
    final m = user ?? const {};
    final grade = _firstOf<Object>(m, ['gradeName', 'grade_name', 'grade', 'stage']);
    String? gradeName;
    if (grade is Map) {
      gradeName = (grade['name'] ?? grade['title'])?.toString();
    } else if (grade != null) {
      gradeName = grade.toString();
    }
    return StudentProfile(
      id: _str(m, ['id', '_id']),
      name: _str(m, ['name', 'fullName', 'full_name']),
      imageUrl: resolveAssetUrl(
        _firstOf<Object>(m, ['profileImagePath', 'profile_image_path', 'avatar', 'image']),
      ),
      gradeName: (gradeName?.trim().isEmpty ?? true) ? null : gradeName!.trim(),
    );
  }
}

class UpcomingLecture {
  const UpcomingLecture({
    required this.courseName,
    required this.teacherName,
    required this.startAt,
    required this.type,
    this.endAt,
    this.courseId,
    this.teacherId,
    this.joinUrl,
  });

  final String courseName;
  final String teacherName;
  final DateTime? startAt;
  final DateTime? endAt;
  final LectureType type;
  final String? courseId;
  final String? teacherId;
  final String? joinUrl;

  /// True when "now" falls inside the session window — drives the live
  /// "ongoing lecture" card with a countdown to [endAt].
  bool get isOngoing {
    final s = startAt, e = endAt;
    if (s == null || e == null) return false;
    final now = DateTime.now();
    return !now.isBefore(s) && now.isBefore(e);
  }

  static UpcomingLecture? fromOverview(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final name = _str(m, ['courseName', 'course_name', 'title', 'name']);
    if (name.isEmpty) return null;
    final teacher = m['teacher'];
    final teacherName = teacher is Map
        ? (teacher['name'] ?? '').toString()
        : _str(m, ['teacherName', 'teacher_name']);
    return UpcomingLecture(
      courseName: name,
      teacherName: teacherName,
      startAt: _date(_firstOf<Object>(m, ['nextOccurrence', 'next_occurrence', 'startAt', 'start_at', 'date'])),
      endAt: _date(_firstOf<Object>(m, ['endAt', 'end_at', 'nextOccurrenceEnd', 'next_occurrence_end'])),
      type: lectureTypeFrom(_firstOf<Object>(m, ['type', 'sessionType', 'session_type', 'courseType', 'course_type'])),
      courseId: _firstOf<Object>(m, ['courseId', 'course_id', 'id'])?.toString(),
      teacherId: teacher is Map ? teacher['id']?.toString() : _firstOf<Object>(m, ['teacherId', 'teacher_id'])?.toString(),
      joinUrl: _firstOf<Object>(m, ['joinUrl', 'join_url', 'meetingUrl', 'meeting_url'])?.toString(),
    );
  }
}

class UpcomingExam {
  const UpcomingExam({
    required this.title,
    required this.courseName,
    required this.examAt,
    this.examId,
  });

  final String title;
  final String courseName;
  final DateTime? examAt;
  final String? examId;

  static UpcomingExam? fromOverview(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final course = _str(m, ['courseName', 'course_name']);
    final title = _str(m, ['title', 'name']);
    if (course.isEmpty && title.isEmpty) return null;
    return UpcomingExam(
      title: title.isEmpty ? course : title,
      courseName: course,
      examAt: _date(_firstOf<Object>(m, ['examDate', 'exam_date', 'date', 'scheduledAt'])),
      examId: _firstOf<Object>(m, ['examId', 'exam_id', 'id'])?.toString(),
    );
  }
}

/// Academic progress percentages (0–100). Each metric is nullable so the UI
/// can render only the meters the backend actually supplies.
class AcademicProgress {
  const AcademicProgress({this.overall, this.attendance, this.assignments, this.exams});

  final int? overall;
  final int? attendance;
  final int? assignments;
  final int? exams;

  /// True when at least one metric carries meaningful (> 0) data — gates the
  /// whole section. A new student's overview returns zeros (not nulls), so a
  /// `> 0` test (not a null test) is what keeps them on the discovery layout
  /// and avoids showing a lone 0% progress card at the start of term.
  bool get hasData => (overall ?? 0) > 0 || (attendance ?? 0) > 0 || (assignments ?? 0) > 0 || (exams ?? 0) > 0;

  factory AcademicProgress.fromOverview(Map<String, dynamic> m) {
    return AcademicProgress(
      overall: _intOrNull(_firstOf<Object>(m, ['progressPercent', 'progress_percent', 'overallProgress', 'overall'])),
      attendance: _intOrNull(_firstOf<Object>(m, ['attendancePercent', 'attendance_percent', 'attendance'])),
      assignments: _intOrNull(_firstOf<Object>(m, ['assignmentsPercent', 'assignments_percent', 'assignmentCompletion', 'homeworkPercent'])),
      exams: _intOrNull(_firstOf<Object>(m, ['examsPercent', 'exams_percent', 'examPerformance', 'examScorePercent'])),
    );
  }
}

class ScheduleLesson {
  const ScheduleLesson({required this.courseName, required this.teacherName, required this.startTime});
  final String courseName;
  final String teacherName;
  final String startTime;

  factory ScheduleLesson.fromJson(Map<String, dynamic> m) {
    final teacher = m['teacher'];
    return ScheduleLesson(
      courseName: _str(m, ['courseName', 'course_name', 'title', 'name']),
      teacherName: teacher is Map ? (teacher['name'] ?? '').toString() : _str(m, ['teacherName', 'teacher_name']),
      startTime: _str(m, ['startTime', 'start_time', 'time']),
    );
  }
}

class WeeklyScheduleDay {
  const WeeklyScheduleDay({required this.weekday, required this.lessons});

  /// ISO weekday-ish key 1–7 as keyed by the backend `scheduleByDay`.
  final int weekday;
  final List<ScheduleLesson> lessons;

  int get count => lessons.length;
}

class MyTeacher {
  MyTeacher({required this.id, required this.name, required this.imageUrl, required this.courses});
  final String id;
  final String name;
  final String imageUrl;
  final List<TeacherCourseRef> courses;

  bool get isActive => courses.any((c) => c.status == 'confirmed' || c.status == 'approved');
  String get mainCourseName => courses.isNotEmpty ? courses.first.name : '';
}

class TeacherCourseRef {
  const TeacherCourseRef({required this.id, required this.name, required this.bookingId, required this.status});
  final String id;
  final String name;
  final String bookingId;
  final String status;
}

class VideoCourseItem {
  const VideoCourseItem({
    required this.id,
    required this.title,
    required this.teacherName,
    required this.thumbnailUrl,
    this.progress,
    this.price,
    this.currency,
  });

  final String id;
  final String title;
  final String teacherName;
  final String thumbnailUrl;

  /// Watch progress 0–1 (for "continue watching"); null when unknown.
  final double? progress;
  final num? price;
  final String? currency;

  factory VideoCourseItem.fromJson(Map<String, dynamic> m) {
    final teacher = m['teacher'];
    final prog = _firstOf<Object>(m, ['progress', 'watchProgress', 'watch_progress', 'completionPercent']);
    double? p;
    if (prog is num) p = prog > 1 ? (prog / 100.0) : prog.toDouble();
    return VideoCourseItem(
      id: _str(m, ['id', '_id', 'videoCourseId']),
      title: _str(m, ['title', 'name', 'courseName', 'course_name']),
      teacherName: teacher is Map ? (teacher['name'] ?? '').toString() : _str(m, ['teacherName', 'teacher_name']),
      thumbnailUrl: resolveAssetUrl(_firstOf<Object>(m, ['coverImage', 'cover_image', 'thumbnail', 'thumbnailUrl', 'thumbnail_url', 'cover', 'image', 'poster'])),
      progress: p,
      price: _firstOf<Object>(m, ['price', 'amount']) is num ? _firstOf<num>(m, ['price', 'amount']) : null,
      currency: _firstOf<Object>(m, ['currency', 'currencyCode'])?.toString(),
    );
  }
}

class NewsItem {
  const NewsItem({required this.id, required this.title, required this.imageUrl, required this.createdAt});
  final String id;
  final String title;
  final String imageUrl;
  final DateTime? createdAt;

  factory NewsItem.fromJson(Map<String, dynamic> m) {
    return NewsItem(
      id: _str(m, ['id', '_id']),
      title: _str(m, ['title', 'headline', 'name']),
      imageUrl: resolveAssetUrl(_firstOf<Object>(m, ['image', 'imageUrl', 'image_url', 'cover', 'thumbnail'])),
      createdAt: _date(_firstOf<Object>(m, ['createdAt', 'created_at', 'publishedAt', 'published_at', 'date'])),
    );
  }
}

class RecommendedTeacher {
  const RecommendedTeacher({required this.id, required this.name, required this.imageUrl, this.subject, this.rating});
  final String id;
  final String name;
  final String imageUrl;
  final String? subject;
  final double? rating;

  factory RecommendedTeacher.fromJson(Map<String, dynamic> m) {
    final r = _firstOf<Object>(m, ['rating', 'avgRating', 'average_rating']);
    final subj = _firstOf<Object>(m, ['subject', 'subjectName', 'subject_name', 'mainSubject']);
    return RecommendedTeacher(
      id: _str(m, ['id', '_id']),
      name: _str(m, ['name', 'fullName', 'full_name']),
      imageUrl: resolveAssetUrl(_firstOf<Object>(m, ['profileImagePath', 'profile_image_path', 'avatar', 'image'])),
      subject: subj is Map ? (subj['name'] ?? '').toString() : subj?.toString(),
      rating: r is num ? r.toDouble() : double.tryParse(r?.toString() ?? ''),
    );
  }
}

class RecommendedCourse {
  const RecommendedCourse({
    required this.id,
    required this.name,
    required this.teacherName,
    required this.imageUrl,
    this.price,
    this.currency,
  });

  final String id;
  final String name;
  final String teacherName;
  final String imageUrl;
  final num? price;
  final String? currency;

  factory RecommendedCourse.fromJson(Map<String, dynamic> m) {
    final images = _firstOf<Object>(m, ['course_images', 'images', 'courseImages']);
    String img = '';
    if (images is List && images.isNotEmpty) img = resolveAssetUrl(images.first);
    img = img.isEmpty ? resolveAssetUrl(_firstOf<Object>(m, ['image', 'cover', 'thumbnail'])) : img;
    final price = _firstOf<Object>(m, ['price', 'amount', 'fee']);
    return RecommendedCourse(
      id: _str(m, ['id', '_id']),
      name: _str(m, ['course_name', 'name', 'title']),
      teacherName: _str(m, ['teacher_name', 'teacherName']),
      imageUrl: img,
      price: price is num ? price : num.tryParse(price?.toString() ?? ''),
      currency: _firstOf<Object>(m, ['currency', 'currencyCode'])?.toString(),
    );
  }
}

/// Aggregate root for the whole screen.
class StudentHomeData {
  const StudentHomeData({
    required this.profile,
    this.upcomingLecture,
    this.upcomingExam,
    this.progress,
    this.weeklySchedule = const [],
    this.myTeachers = const [],
    this.myVideoCourses = const [],
    this.news = const [],
    this.recommendedTeachers = const [],
    this.recommendedCourses = const [],
    this.recommendedVideoCourses = const [],
    this.streakDays,
  });

  final StudentProfile profile;
  final UpcomingLecture? upcomingLecture;
  final UpcomingExam? upcomingExam;
  final AcademicProgress? progress;
  final List<WeeklyScheduleDay> weeklySchedule;
  final List<MyTeacher> myTeachers;
  final List<VideoCourseItem> myVideoCourses;
  final List<NewsItem> news;
  final List<RecommendedTeacher> recommendedTeachers;
  final List<RecommendedCourse> recommendedCourses;
  final List<VideoCourseItem> recommendedVideoCourses;
  final int? streakDays;

  bool get hasWeeklySchedule => weeklySchedule.any((d) => d.count > 0);
  bool get hasProgress => progress?.hasData ?? false;

  /// A new student has no learning relationships yet: no teachers, no
  /// schedule, no owned video courses, and no upcoming activity or progress.
  bool get isNewStudent =>
      myTeachers.isEmpty &&
      !hasWeeklySchedule &&
      myVideoCourses.isEmpty &&
      upcomingLecture == null &&
      upcomingExam == null &&
      !hasProgress;
}
