import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/core/config/app_config.dart';
import 'package:mulhimiq/shared/widgets/unified_video_player/unified_video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class TeacherDetailsScreen extends StatefulWidget {
  final String teacherId;
  const TeacherDetailsScreen({super.key, required this.teacherId});

  @override
  State<TeacherDetailsScreen> createState() => _TeacherDetailsScreenState();
}

class _TeacherDetailsScreenState extends State<TeacherDetailsScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _teacher;
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _courses = [];
  // Intro video state
  bool _introLoading = true;
  String? _introError;
  Map<String, dynamic>? _introData; // response.data
  String?
  _contentBase; // response.content_url normalized without trailing slash

  // Unified-hub state — enrollments the student has WITH THIS TEACHER.
  // Filtered client-side from /api/student/enrollments so we don't change
  // the backend contract for this unification pass.
  bool _enrollmentsLoading = true;
  List<Map<String, dynamic>> _myEnrollments = const [];
  // Set of courseIds the student already owns/enrolled in — used to stamp a
  // "مملوكة" badge on cards in the "available courses" section so a single
  // available-courses tap from either entry point is unambiguous.
  Set<String> _ownedCourseIds = const {};

  @override
  void initState() {
    super.initState();
    _load();
    _loadIntro();
    _loadMyEnrollments();
  }

  /// Pull-to-refresh entry point — re-invokes EVERY section's fetch in
  /// parallel so the unified hub reflects fresh server state on a tug.
  Future<void> _refreshAll() async {
    await Future.wait<void>([_load(), _loadIntro(), _loadMyEnrollments()]);
  }

  /// Loads the student's enrollments and filters to the ones with THIS
  /// teacher. Existing endpoint, no backend change. Errors are swallowed
  /// — the section just degrades to "no courses with this teacher" if the
  /// fetch fails, which is the same visual state as a fresh student.
  Future<void> _loadMyEnrollments() async {
    setState(() => _enrollmentsLoading = true);
    try {
      // The enrollments endpoint paginates; for the teacher-hub view we
      // want everything the student owns with this teacher. limit=200 is
      // a pragmatic upper bound — a single teacher rarely has more than
      // a handful of courses per student.
      final res = await _api.fetchStudentEnrollments(page: 1, limit: 200);
      final all = (res['data'] is List)
          ? List<Map<String, dynamic>>.from(res['data'])
          : <Map<String, dynamic>>[];
      final mine = all.where((row) {
        final t = (row['teacher'] is Map) ? row['teacher'] as Map : const {};
        return (t['id'] ?? '').toString() == widget.teacherId;
      }).toList();
      final owned = <String>{};
      for (final row in mine) {
        final c = (row['course'] is Map) ? row['course'] as Map : const {};
        final id = (c['id'] ?? '').toString();
        if (id.isNotEmpty) owned.add(id);
      }
      if (!mounted) return;
      setState(() {
        _myEnrollments = mine;
        _ownedCourseIds = owned;
      });
    } catch (_) {
      // Best-effort — keep prior state, just stop spinning.
    } finally {
      if (mounted) setState(() => _enrollmentsLoading = false);
    }
  }

  /// Open a course the student already owns. Mirrors the navigation rule
  /// from enrollments_screen.dart so behaviour stays identical whether
  /// the student tapped from My Courses, My Teachers home, or this hub.
  void _openOwnedCourse(Map<String, dynamic> course, {String? bookingId, String? status}) {
    final id = (course['id'] ?? '').toString();
    final name = (course['name'] ?? course['course_name'] ?? '').toString();
    if (id.isEmpty) return;
    final route = AppConfig.useNewCourseHub ? '/course-hub' : '/enrollment-actions';
    Get.toNamed(route, arguments: {
      'courseId': id,
      'courseName': name,
      'teacherId': widget.teacherId,
      if (bookingId != null && bookingId.isNotEmpty) 'bookingId': bookingId,
      if (status != null && status.isNotEmpty) 'status': status,
    });
  }

  /// Open a non-owned course's public details — preserves the existing
  /// purchase / free-access path the student would have hit from the
  /// suggested-courses surface.
  void _openCourseDetails(String courseId) {
    if (courseId.isEmpty) return;
    Get.toNamed('/course-details', arguments: courseId);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.fetchTeacherSubjectsCourses(widget.teacherId);
      setState(() {
        _teacher = Map<String, dynamic>.from(data['teacher'] ?? {});
        _subjects = List<Map<String, dynamic>>.from(data['subjects'] ?? []);
        _courses = List<Map<String, dynamic>>.from(data['courses'] ?? []);
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadIntro() async {
    setState(() {
      _introLoading = true;
      _introError = null;
    });
    try {
      final res = await _api.fetchTeacherIntroVideo(widget.teacherId);
      final base = (res['content_url']?.toString() ?? '').replaceAll(
        RegExp(r"/+$"),
        '',
      );
      final data = Map<String, dynamic>.from(res['data'] ?? {});
      setState(() {
        _introData = data;
        _contentBase = base.isEmpty ? AppConfig.serverBaseUrl : base;
      });
    } catch (e) {
      setState(() => _introError = e.toString());
    } finally {
      if (mounted) setState(() => _introLoading = false);
    }
  }

  String _absFromContent(String? p) {
    if (p == null || p.isEmpty) return '';
    final base = (_contentBase ?? AppConfig.serverBaseUrl).replaceAll(
      RegExp(r"/+$"),
      '',
    );
    if (p.startsWith('http')) return p;
    if (p.startsWith('/')) return '$base$p';
    return '$base/$p';
  }

  // Phase 7 — Intro video uses UnifiedVideoPlayer directly. The widget
  // owns its own controller + disposal so we no longer need a setup
  // helper or a dispose hook here.

  @override
  void dispose() {
    super.dispose();
  }

  double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  Future<void> _openOnMaps() async {
    final lat = _toDouble(_teacher?['latitude']);
    final lng = _toDouble(_teacher?['longitude']);
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('إحداثيات المعلم غير متوفرة')),
      );
      return;
    }

    final latStr = lat.toStringAsFixed(6);
    final lngStr = lng.toStringAsFixed(6);
    final googleMapsUri = Uri.parse('comgooglemaps://?q=$latStr,$lngStr');
    final fallbackWebUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latStr,$lngStr',
    );

    try {
      if (await canLaunchUrl(googleMapsUri)) {
        await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(fallbackWebUri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح الخرائط')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = (_teacher?['name'] ?? _teacher?['full_name'] ?? '').toString();
    return Scaffold(
      appBar: AppBar(title: Text(name.isEmpty ? 'تفاصيل المعلم' : name)),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 200),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : (_error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [SizedBox(height: 80), _buildError(cs)],
                  )
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildIntroVideoSection(cs),
                        const SizedBox(height: 16),
                        if (_subjects.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _subjects
                                .map(
                                  (s) => Chip(
                                    label: Text(
                                      s['name'] ?? '',
                                      style: TextStyle(
                                        color: cs.onSecondaryContainer,
                                      ),
                                    ),
                                    backgroundColor: cs.secondaryContainer,
                                  ),
                                )
                                .toList(),
                          ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _openOnMaps,
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('عرض موقع المعلم على الخريطة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // ─── My courses with THIS teacher ───────────────
                        // Only renders when the student actually has at
                        // least one enrollment with this teacher. The
                        // fetch is best-effort; on failure the section
                        // silently collapses (same visual as a fresh
                        // student) so it can never break the screen.
                        if (_enrollmentsLoading && _myEnrollments.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'جارٍ تحميل دوراتك مع هذا الأستاذ…',
                                  style: TextStyle(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          )
                        else if (_myEnrollments.isNotEmpty) ...[
                          _sectionHeader(cs, 'دوراتي مع هذا الأستاذ',
                              count: _myEnrollments.length),
                          const SizedBox(height: 12),
                          ..._myEnrollments.map(
                            (row) => _buildEnrolledCourseCard(row, cs, isDark),
                          ),
                          const SizedBox(height: 24),
                        ],
                        _sectionHeader(
                          cs,
                          _myEnrollments.isEmpty
                              ? 'الدورات'
                              : 'الدورات المتاحة',
                          count: _courses.length,
                        ),
                        const SizedBox(height: 12),
                        if (_courses.isEmpty)
                          Text(
                            'لا توجد دورات حالياً',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          )
                        else
                          ..._courses.asMap().entries.map(
                            (e) => _buildCourseItem(e.value, e.key, cs, isDark),
                          ),
                      ],
                    ),
                  )),
      ),
    );
  }

  Widget _sectionHeader(ColorScheme cs, String title, {int? count}) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
        ),
        if (count != null && count > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: cs.onPrimaryContainer,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Card for a course the student is ALREADY enrolled in. Tap → same
  /// destination the My Courses tab routes to today (enrollment-actions
  /// or course-hub depending on the AppConfig.useNewCourseHub flag).
  Widget _buildEnrolledCourseCard(
    Map<String, dynamic> row,
    ColorScheme cs,
    bool isDark,
  ) {
    final course = (row['course'] is Map)
        ? Map<String, dynamic>.from(row['course'])
        : <String, dynamic>{};
    final status = (row['status'] ?? '').toString();
    final bookingId = (row['bookingId'] ?? row['booking_id'] ?? '').toString();
    final name = (course['name'] ?? course['course_name'] ?? 'دورة').toString();

    final images = (course['course_images'] is List)
        ? (course['course_images'] as List)
        : const [];
    final img = images.isNotEmpty ? images.first?.toString() : null;
    String imgUrl;
    if (img == null || img.isEmpty) {
      imgUrl = '';
    } else if (img.startsWith('http')) {
      imgUrl = img;
    } else {
      imgUrl = '${AppConfig.serverBaseUrl}$img';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.45)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openOwnedCourse(course, bookingId: bookingId, status: status),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: imgUrl.isEmpty
                      ? Container(
                          color: cs.surfaceContainerHighest,
                          child: Icon(Icons.play_circle_outline,
                              color: cs.primary),
                        )
                      : Image.network(
                          imgUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: cs.surfaceContainerHighest,
                            child: Icon(Icons.play_circle_outline,
                                color: cs.primary),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'مملوكة',
                          style: TextStyle(
                            color: cs.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (status.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          'الحالة: $status',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () =>
                    _openOwnedCourse(course, bookingId: bookingId, status: status),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('متابعة'),
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroVideoSection(ColorScheme cs) {
    if (_introLoading) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('جاري تحميل الفيديو التعريفي...'),
          ],
        ),
      );
    }

    if (_introError != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(_introError!, style: TextStyle(color: cs.onErrorContainer)),
      );
    }

    final data = _introData ?? const {};
    final status = (data['status'] ?? 'none').toString();
    if (status != 'ready') {
      final msg =
          {
            'processing': 'الفيديو قيد المعالجة، حاول لاحقاً',
            'failed': 'تعذر تجهيز الفيديو التعريفي',
            'none': 'لا يوجد فيديو تعريفي',
          }[status] ??
          'لا يوجد فيديو تعريفي';
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(msg, style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          ],
        ),
      );
    }

    final manifest = data['manifestUrl']?.toString() ?? '';
    final thumb = data['thumbnailUrl']?.toString() ?? '';
    final manifestAbs = manifest.isEmpty ? '' : _absFromContent(manifest);
    final thumbAbs = thumb.isEmpty ? null : _absFromContent(thumb);

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: manifestAbs.isEmpty
            ? Container(color: cs.surfaceContainerHighest)
            : UnifiedVideoPlayer(
                videoUrl: manifestAbs,
                videoId: 'teacher-intro:${widget.teacherId}',
                thumbnailUrl: thumbAbs,
                autoPlay: false,
              ),
      ),
    );
  }

  Widget _buildError(ColorScheme cs) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: cs.error, size: 36),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _load, child: const Text('إعادة المحاولة')),
        ],
      ),
    ),
  );

  Widget _buildCourseItem(
    Map<String, dynamic> course,
    int index,
    ColorScheme cs,
    bool isDark,
  ) {
    final images = (course['course_images'] is List)
        ? (course['course_images'] as List)
        : const [];
    final img = images.isNotEmpty ? images.first?.toString() : null;
    String imgUrl;
    if (img == null || img.isEmpty) {
      imgUrl = '';
    } else if (img.startsWith('http')) {
      imgUrl = img;
    } else {
      imgUrl = '${AppConfig.serverBaseUrl}$img';
    }

    final priceNum = (course['price'] is num)
        ? (course['price'] as num).toDouble()
        : double.tryParse(course['price']?.toString() ?? '0') ?? 0;
    final priceStr = NumberFormat('#,###').format(priceNum);

    final subjectName = course['subject'] is Map
        ? (course['subject']['name'] ?? '').toString()
        : (course['subject_name'] ?? '').toString();

    final courseId = (course['id'] ?? '').toString();
    final isOwned = courseId.isNotEmpty && _ownedCourseIds.contains(courseId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? cs.primary.withValues(alpha: 0.3) : cs.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        // Owned → existing enrollment-actions surface (preserves Continue
        // flow). Not owned → existing /course-details surface (preserves
        // the suggested-courses purchase / free-access flow).
        onTap: courseId.isEmpty
            ? null
            : (isOwned
                ? () => _openOwnedCourse(course)
                : () => _openCourseDetails(courseId)),
        child: ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 52,
              height: 52,
              color: cs.surfaceContainerHighest,
              child: imgUrl.isEmpty
                  ? Icon(Icons.school, color: cs.onSurfaceVariant)
                  : Image.network(
                      imgUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Icon(Icons.school, color: cs.onSurfaceVariant),
                    ),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  course['course_name'] ?? '',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: cs.onSurface),
                ),
              ),
              if (isOwned)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'مملوكة',
                    style: TextStyle(
                      color: cs.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'المادة: $subjectName\nالسعر: $priceStr د.ع',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
