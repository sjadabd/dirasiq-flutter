// Teacher → "الدورات المرئية" — list view + create dialog.
//
// Matches the dashboard's /teacher/video-courses index:
//   - Status tabs (all / pending_review / approved / hidden / rejected).
//   - Compact card grid (2 cols on phone, 3 on tablet).
//   - "Create new course" dialog where subject + teachingStage are
//     DROPDOWNS sourced from the teacher's own subjects + grades.
//
// Per-course tap → teacher_video_course_detail_screen.dart.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/realtime_service.dart';
import '../../../core/services/teacher_api_service.dart';
import '../../../shared/widgets/app_network_image.dart';
import 'teacher_video_course_detail_screen.dart';
import 'widgets/video_course_form_dialog.dart';

class TeacherVideoCoursesScreen extends StatefulWidget {
  const TeacherVideoCoursesScreen({super.key});

  @override
  State<TeacherVideoCoursesScreen> createState() => _TeacherVideoCoursesScreenState();
}

class _TeacherVideoCoursesScreenState extends State<TeacherVideoCoursesScreen> {
  static const _statuses = <Map<String, dynamic>>[
    {'value': 'all',            'label': 'الكل',              'color': Colors.grey},
    {'value': 'pending_review', 'label': 'بانتظار المراجعة', 'color': Colors.orange},
    {'value': 'approved',       'label': 'مقبولة',           'color': Colors.green},
    {'value': 'hidden',         'label': 'مخفية',            'color': Colors.blueGrey},
    {'value': 'rejected',       'label': 'مرفوضة',           'color': Colors.red},
  ];

  final _api = TeacherApiService();

  String _status = 'all';
  bool _loading = false;
  List<Map<String, dynamic>> _items = [];
  String _error = '';

  // Unsubscribe handle for the realtime listeners.
  void Function()? _unsubCourseStatus;

  @override
  void initState() {
    super.initState();
    _fetch();

    // When the admin approves / rejects ANY of this teacher's courses, the
    // list view should reflect it without a manual refresh. The detail
    // screen also subscribes and matches by id; here we refetch the whole
    // list because the row could move between status tabs.
    void onCourseStatusChange(dynamic data, {required bool approved}) {
      if (!mounted) return;
      final course = (data is Map && data['course'] is Map)
          ? Map<String, dynamic>.from(data['course'] as Map)
          : null;
      if (course == null) return;
      _fetch();
      // Two-step remove + post-frame show — clearSnackBars alone races
      // with Material's Hero teardown when identical-text snackbars
      // arrive back-to-back. See teacher_video_course_detail_screen
      // _snack() for the full rationale.
      final messenger = ScaffoldMessenger.of(context);
      messenger.removeCurrentSnackBar();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(
          content: Text(approved
              ? 'تمت الموافقة على دورة "${course['title'] ?? ''}"'
              : 'تم رفض دورة "${course['title'] ?? ''}"'),
          backgroundColor: approved ? Colors.green : Colors.redAccent,
        ));
      });
    }

    final approveUnsub = RealtimeService.instance.subscribe(
      'video-course:approved',
      (d) => onCourseStatusChange(d, approved: true),
    );
    final rejectUnsub = RealtimeService.instance.subscribe(
      'video-course:rejected',
      (d) => onCourseStatusChange(d, approved: false),
    );
    _unsubCourseStatus = () { approveUnsub(); rejectUnsub(); };
  }

  @override
  void dispose() {
    _unsubCourseStatus?.call();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final res = await _api.fetchMyVideoCourses(status: _status);
      final list = res['data'];
      _items = (list is List)
          ? list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
          : [];
    } catch (e) {
      _error = 'تعذّر تحميل الدورات';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreateDialog() async {
    final id = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const VideoCourseFormDialog(),
    );
    if (id != null && mounted) {
      await Get.to(() => TeacherVideoCourseDetailScreen(courseId: id));
      _fetch(); // refresh after returning so any inline edits land
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('دوراتي المرئية'),
        backgroundColor: scheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _loading ? null : _fetch,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('دورة جديدة'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: _statuses.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final s = _statuses[i];
                final selected = _status == s['value'];
                return ChoiceChip(
                  label: Text(s['label']),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _status = s['value']);
                    _fetch();
                  },
                );
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(child: Text(_error, style: TextStyle(color: scheme.error)))
                    : _items.isEmpty
                        ? const _EmptyState()
                        : RefreshIndicator(
                            onRefresh: _fetch,
                            child: GridView.builder(
                              padding: const EdgeInsets.all(12),
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 220,
                                mainAxisExtent: 220,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              itemCount: _items.length,
                              itemBuilder: (_, i) {
                                final c = _items[i];
                                return _CourseCard(
                                  course: c,
                                  onTap: () async {
                                    await Get.to(() => TeacherVideoCourseDetailScreen(
                                          courseId: c['id'].toString(),
                                        ));
                                    _fetch();
                                  },
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.video_library_outlined, size: 64, color: scheme.outline),
          const SizedBox(height: 12),
          Text('لا توجد دورات في هذه الحالة',
              style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course, required this.onTap});
  final Map<String, dynamic> course;
  final VoidCallback onTap;

  Map<String, dynamic> _statusVisuals(String s) {
    switch (s) {
      case 'pending_review': return {'label': 'بانتظار المراجعة', 'color': Colors.orange};
      case 'approved':       return {'label': 'مقبولة',           'color': Colors.green};
      case 'hidden':         return {'label': 'مخفية',            'color': Colors.blueGrey};
      case 'rejected':       return {'label': 'مرفوضة',           'color': Colors.red};
      default:               return {'label': s,                  'color': Colors.grey};
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cover = course['coverImage']?.toString() ?? '';
    final status = course['status']?.toString() ?? '';
    final sv = _statusVisuals(status);
    final isFree = course['isFree'] == true;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // AppNetworkImage handles empty / loading / failed states
                  // with a light placeholder — avoids the black-frame bug
                  // that came from the previous theme-derived fallback.
                  AppNetworkImage(
                    url: cover,
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.movie_outlined,
                  ),
                  Positioned(
                    top: 6, right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (sv['color'] as Color).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(sv['label'],
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course['title']?.toString() ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${course['subject'] ?? '—'} · ${course['teachingStage'] ?? '—'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                    const Spacer(),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isFree ? Colors.green : Colors.orange).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isFree ? 'مجاني' : '${course['price'] ?? 0} د.ع',
                          style: TextStyle(
                            color: isFree ? Colors.green.shade700 : Colors.orange.shade800,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

