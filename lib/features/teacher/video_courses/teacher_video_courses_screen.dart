// Teacher → "الدورات المرئية" — list view + create dialog.
//
// Teacher Design System pass. Presentation only — fetchMyVideoCourses, the
// realtime approve/reject subscriptions, and the create flow
// (VideoCourseFormDialog) are UNCHANGED. Restyled to the teacher design system
// (hero + MqChip status filters + design-system thumbnail cards).

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/realtime_service.dart';
import '../../../core/services/teacher_api_service.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../shared/design/teacher_design.dart';
import '../shared/teacher_app_bar.dart';
import '../shared/teacher_drawer.dart';
import 'teacher_video_course_detail_screen.dart';
import 'widgets/video_course_form_dialog.dart';

class TeacherVideoCoursesScreen extends StatefulWidget {
  const TeacherVideoCoursesScreen({super.key});

  @override
  State<TeacherVideoCoursesScreen> createState() =>
      _TeacherVideoCoursesScreenState();
}

class _TeacherVideoCoursesScreenState extends State<TeacherVideoCoursesScreen> {
  static const _statuses = <(String, String)>[
    ('all', 'الكل'),
    ('pending_review', 'بانتظار المراجعة'),
    ('approved', 'مقبولة'),
    ('hidden', 'مخفية'),
    ('rejected', 'مرفوضة'),
  ];

  final _api = TeacherApiService();

  String _status = 'all';
  bool _loading = false;
  List<Map<String, dynamic>> _items = [];
  String _error = '';

  void Function()? _unsubCourseStatus;

  @override
  void initState() {
    super.initState();
    _fetch();

    void onCourseStatusChange(dynamic data, {required bool approved}) {
      if (!mounted) return;
      final course = (data is Map && data['course'] is Map)
          ? Map<String, dynamic>.from(data['course'] as Map)
          : null;
      if (course == null) return;
      _fetch();
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
    _unsubCourseStatus = () {
      approveUnsub();
      rejectUnsub();
    };
  }

  @override
  void dispose() {
    _unsubCourseStatus?.call();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = '';
    });
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
    final id = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const VideoCourseFormDialog(),
    );
    if (id != null && mounted) {
      await Get.to(() => TeacherVideoCourseDetailScreen(courseId: id));
      _fetch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: isDark ? MqTheme.dark() : MqTheme.light(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(builder: (context) {
          final mq = context.mq;
          return Scaffold(
            backgroundColor: mq.page,
            appBar: TeacherAppBar(
              title: 'الدورات المرئية',
              actions: [_RefreshAction(loading: _loading, onTap: _fetch)],
            ),
            drawer: const TeacherDrawer(),
            floatingActionButton: FloatingActionButton(
              onPressed: _openCreateDialog,
              backgroundColor: mq.accent,
              foregroundColor: mq.onAccent,
              elevation: 3,
              tooltip: 'دورة جديدة',
              shape: const RoundedRectangleBorder(borderRadius: MqRadius.brLg),
              child: const Icon(Icons.add_rounded),
            ),
            body: Column(
              children: [
                _hero(context),
                _filters(context),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error.isNotEmpty
                          ? Center(
                              child: Text(_error,
                                  style: context.text.bodyMedium
                                      ?.copyWith(color: mq.error)))
                          : _items.isEmpty
                              ? const _EmptyState()
                              : RefreshIndicator(
                                  onRefresh: _fetch,
                                  color: mq.accent,
                                  child: GridView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                        MqSpacing.lg, 0, MqSpacing.lg, 96),
                                    gridDelegate:
                                        const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 220,
                                      mainAxisExtent: 224,
                                      crossAxisSpacing: MqSpacing.md,
                                      mainAxisSpacing: MqSpacing.md,
                                    ),
                                    itemCount: _items.length,
                                    itemBuilder: (_, i) {
                                      final c = _items[i];
                                      return _CourseCard(
                                        course: c,
                                        onTap: () async {
                                          await Get.to(() =>
                                              TeacherVideoCourseDetailScreen(
                                                  courseId:
                                                      c['id'].toString()));
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
        }),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    final t = context.teacher;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          MqSpacing.lg, MqSpacing.lg, MqSpacing.lg, MqSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(MqSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [t.heroA, t.heroB],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: MqRadius.brXl,
          boxShadow: t.shadowLg,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: context.mq.orange, shape: BoxShape.circle),
              child: const Icon(Icons.video_library_outlined,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: MqSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الدورات المرئية',
                      style:
                          context.text.titleMedium?.copyWith(color: t.heroInk)),
                  const SizedBox(height: 2),
                  Text('${_items.length} دورة',
                      style:
                          context.text.labelSmall?.copyWith(color: t.heroInk2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filters(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: MqSpacing.lg),
        scrollDirection: Axis.horizontal,
        itemCount: _statuses.length,
        separatorBuilder: (_, _) => const SizedBox(width: MqSpacing.sm),
        itemBuilder: (_, i) {
          final (value, label) = _statuses[i];
          return MqChip(
            label: label,
            selected: _status == value,
            onTap: () {
              setState(() => _status = value);
              _fetch();
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _RefreshAction extends StatelessWidget {
  const _RefreshAction({required this.loading, required this.onTap});
  final bool loading;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MqSpacing.xs),
      child: Material(
        color: mq.fill,
        shape: RoundedRectangleBorder(
          borderRadius: MqRadius.brMd,
          side: BorderSide(color: mq.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: loading ? null : () => onTap(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: loading
                ? Padding(
                    padding: const EdgeInsets.all(11),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: mq.ink3),
                  )
                : Icon(Icons.refresh_rounded,
                    size: MqSize.iconSm, color: mq.ink2),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: mq.fill2, shape: BoxShape.circle),
            child: Icon(Icons.video_library_outlined, size: 34, color: mq.ink3),
          ),
          const SizedBox(height: MqSpacing.md),
          Text('لا توجد دورات في هذه الحالة',
              style: context.text.bodyMedium?.copyWith(color: mq.ink2)),
          const SizedBox(height: MqSpacing.xs),
          Text('أنشئ دورتك من زر «دورة جديدة»',
              style: context.text.bodySmall?.copyWith(color: mq.ink3)),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course, required this.onTap});
  final Map<String, dynamic> course;
  final VoidCallback onTap;

  (String, TeacherTone) _statusMeta(String s) {
    switch (s) {
      case 'pending_review':
        return ('بانتظار المراجعة', TeacherTone.warning);
      case 'approved':
        return ('مقبولة', TeacherTone.success);
      case 'hidden':
        return ('مخفية', TeacherTone.neutral);
      case 'rejected':
        return ('مرفوضة', TeacherTone.danger);
      default:
        return (s, TeacherTone.neutral);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final t = context.teacher;
    final cover = course['coverImage']?.toString() ?? '';
    final (statusLabel, statusTone) =
        _statusMeta(course['status']?.toString() ?? '');
    final statusColor = switch (statusTone) {
      TeacherTone.warning => t.warning,
      TeacherTone.success => t.success,
      TeacherTone.danger => t.danger,
      _ => mq.ink2,
    };
    final isFree = course['isFree'] == true;

    return MqCard(
      padding: EdgeInsets.zero,
      borderRadius: MqRadius.brLg,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: MqRadius.brLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppNetworkImage(
                    url: cover,
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.movie_outlined,
                  ),
                  PositionedDirectional(
                    top: 6,
                    end: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: MqSpacing.sm, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: MqRadius.brPill,
                      ),
                      child: Text(statusLabel,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(MqSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course['title']?.toString() ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${course['subject'] ?? '—'} · ${course['teachingStage'] ?? '—'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(color: mq.ink3),
                    ),
                    const Spacer(),
                    MqBadge(
                      label: isFree ? 'مجاني' : '${fmtMoney(course['price'])} د.ع',
                      tone: isFree ? MqBadgeTone.success : MqBadgeTone.orange,
                    ),
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
