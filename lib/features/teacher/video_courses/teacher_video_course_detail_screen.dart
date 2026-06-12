// Teacher video-course detail (Teacher Design System pass).
//
// Presentation only — _fetchAll, the realtime lesson/course subscriptions,
// cover upload, lesson CRUD (add/edit/replace/delete/sync), reorder, and
// playback are UNCHANGED. Restyled to the teacher design system; the edit-
// lesson dialog is now an animated bottom sheet.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/realtime_service.dart';
import '../../../core/services/teacher_api_service.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/unified_video_player/unified_video_player_screen.dart';
import '../shared/design/teacher_design.dart';
import '../shared/teacher_app_bar.dart';
import 'widgets/video_course_form_dialog.dart';
import 'widgets/video_lesson_upload_dialog.dart';

class TeacherVideoCourseDetailScreen extends StatefulWidget {
  const TeacherVideoCourseDetailScreen({super.key, required this.courseId});
  final String courseId;

  @override
  State<TeacherVideoCourseDetailScreen> createState() =>
      _TeacherVideoCourseDetailScreenState();
}

class _TeacherVideoCourseDetailScreenState
    extends State<TeacherVideoCourseDetailScreen> {
  final _api = TeacherApiService();

  bool _loading = true;
  String _error = '';
  Map<String, dynamic>? _course;
  List<Map<String, dynamic>> _lessons = [];

  bool _coverUploading = false;
  bool _reorderMode = false;
  bool _reorderBusy = false;

  void Function()? _unsubLessonStatus;
  void Function()? _unsubCourseStatus;

  static (String, TeacherTone) _courseStatus(String s) {
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

  static (String, TeacherTone) _bunnyStatus(String s) {
    switch (s) {
      case 'pending':
        return ('بانتظار الرفع', TeacherTone.neutral);
      case 'uploaded':
        return ('تم الرفع', TeacherTone.info);
      case 'processing':
        return ('قيد المعالجة', TeacherTone.warning);
      case 'ready':
        return ('جاهز', TeacherTone.success);
      case 'failed':
        return ('فشل', TeacherTone.danger);
      default:
        return (s, TeacherTone.neutral);
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchAll();
    _attachRealtime();
  }

  @override
  void dispose() {
    _unsubLessonStatus?.call();
    _unsubCourseStatus?.call();
    super.dispose();
  }

  void _attachRealtime() {
    _unsubLessonStatus = RealtimeService.instance.subscribe(
      'video-lesson:status_changed',
      (data) {
        if (!mounted) return;
        final lesson = (data is Map && data['lesson'] is Map)
            ? Map<String, dynamic>.from(data['lesson'] as Map)
            : null;
        if (lesson == null) return;
        if (lesson['courseId']?.toString() != widget.courseId) return;

        final lessonId = lesson['id']?.toString();
        if (lessonId != null && lessonId.isNotEmpty) {
          final idx =
              _lessons.indexWhere((l) => l['id']?.toString() == lessonId);
          if (idx >= 0) {
            setState(() {
              _lessons[idx] = {..._lessons[idx], ...lesson};
            });
          } else {
            _fetchAll();
          }
        }

        final status = lesson['bunnyStatus']?.toString();
        if (status == 'ready') {
          _snack('تم تجهيز فيديو الدرس "${lesson['title'] ?? ''}"');
        } else if (status == 'failed') {
          _snack('فشل معالجة فيديو الدرس "${lesson['title'] ?? ''}"',
              error: true);
        }
      },
    );

    void onCourseStatus(dynamic data, {required bool approved}) {
      if (!mounted) return;
      final course = (data is Map && data['course'] is Map)
          ? Map<String, dynamic>.from(data['course'] as Map)
          : null;
      if (course == null) return;
      if (course['id']?.toString() != widget.courseId) return;
      _fetchAll();
      _snack(
        approved
            ? 'تمت الموافقة على الدورة من قبل الإدارة'
            : 'تم رفض الدورة من قبل الإدارة',
        error: !approved,
      );
    }

    final approveUnsub = RealtimeService.instance.subscribe(
      'video-course:approved',
      (d) => onCourseStatus(d, approved: true),
    );
    final rejectUnsub = RealtimeService.instance.subscribe(
      'video-course:rejected',
      (d) => onCourseStatus(d, approved: false),
    );
    _unsubCourseStatus = () {
      approveUnsub();
      rejectUnsub();
    };
  }

  Future<void> _fetchAll() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final results = await Future.wait([
        _api.fetchMyVideoCourse(widget.courseId),
        _api.fetchMyVideoCourseLessons(widget.courseId),
      ]);
      final c = results[0]['data']?['course'];
      final l = results[1]['data']?['lessons'];
      _course = (c is Map) ? Map<String, dynamic>.from(c) : null;
      _lessons = (l is List)
          ? l.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
          : [];
    } catch (_) {
      _error = 'تعذّر تحميل تفاصيل الدورة';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ----- Course actions ----------------------------------------------------

  Future<void> _openEditDialog() async {
    if (_course == null) return;
    final id = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VideoCourseFormDialog(initial: _course),
    );
    if (id != null) {
      _snack('تم حفظ التعديلات. الدورة الآن قيد المراجعة من جديد.');
      _fetchAll();
    }
  }

  Future<void> _changeCover() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );
      if (res == null || res.files.isEmpty) return;
      final path = res.files.single.path;
      if (path == null) return;
      setState(() => _coverUploading = true);
      await _api.uploadVideoCourseCoverImage(widget.courseId, path);
      await _fetchAll();
      _snack('تم تحديث صورة الغلاف.');
    } catch (e) {
      _snack('تعذّر رفع صورة الغلاف: $e', error: true);
    } finally {
      if (mounted) setState(() => _coverUploading = false);
    }
  }

  Future<void> _askDeleteCourse() async {
    final ok = await _confirmDialog(
      title: 'حذف الدورة',
      message:
          'سيتم حذف الدورة وجميع دروسها. الإجراء غير قابل للاسترجاع من واجهة الأستاذ.',
      confirmLabel: 'حذف',
      destructive: true,
    );
    if (ok != true) return;
    try {
      await _api.deleteVideoCourse(widget.courseId);
      if (!mounted) return;
      _snack('تم حذف الدورة.');
      Navigator.of(context).pop();
    } catch (e) {
      _snack('تعذّر الحذف: $e', error: true);
    }
  }

  // ----- Lesson actions ----------------------------------------------------

  Future<void> _openAddLessonDialog() async {
    final newId = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VideoLessonUploadDialog(courseId: widget.courseId),
    );
    if (newId != null) _fetchAll();
  }

  Future<void> _replaceLessonVideo(Map<String, dynamic> lesson) async {
    final ok = await _confirmDialog(
      title: 'استبدال فيديو الدرس',
      message: 'سيتم حذف الفيديو الحالي ورفع فيديو جديد. هل أنت متأكد؟',
      confirmLabel: 'متابعة',
    );
    if (ok != true) return;
    if (!mounted) return;
    final newId = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VideoLessonUploadDialog(
        courseId: widget.courseId,
        replaceLessonId: lesson['id']?.toString(),
        initialTitle: lesson['title']?.toString(),
        initialDescription: lesson['description']?.toString(),
      ),
    );
    if (newId != null) _fetchAll();
  }

  Future<void> _openEditLessonDialog(Map<String, dynamic> lesson) async {
    final title =
        TextEditingController(text: lesson['title']?.toString() ?? '');
    final description =
        TextEditingController(text: lesson['description']?.toString() ?? '');
    String err = '';
    bool submitting = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Theme(
        data: isDark ? MqTheme.dark() : MqTheme.light(),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(builder: (ctx, setS) {
            final mq = ctx.mq;
            return Padding(
              padding:
                  EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: mq.card,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(MqRadius.xl)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(MqSpacing.lg,
                        MqSpacing.sm, MqSpacing.lg, MqSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: MqSpacing.md),
                            decoration: BoxDecoration(
                                color: mq.line, borderRadius: MqRadius.brPill),
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                  color: mq.accentSoft,
                                  borderRadius: MqRadius.brSm),
                              child: Icon(Icons.edit_outlined,
                                  size: MqSize.iconSm, color: mq.accent),
                            ),
                            const SizedBox(width: MqSpacing.sm),
                            Expanded(
                              child: Text('تعديل بيانات الدرس',
                                  style: ctx.text.titleMedium),
                            ),
                            InkWell(
                              onTap: submitting
                                  ? null
                                  : () => Navigator.pop(ctx, false),
                              customBorder: const CircleBorder(),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child:
                                    Icon(Icons.close_rounded, color: mq.ink3),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: MqSpacing.lg),
                        TextField(
                          controller: title,
                          enabled: !submitting,
                          decoration: const InputDecoration(
                            labelText: 'عنوان الدرس *',
                            prefixIcon: Icon(Icons.title_rounded),
                          ),
                        ),
                        const SizedBox(height: MqSpacing.md),
                        TextField(
                          controller: description,
                          enabled: !submitting,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'الوصف',
                            hintText: 'وصف اختياري...',
                          ),
                        ),
                        if (err.isNotEmpty) ...[
                          const SizedBox(height: MqSpacing.sm),
                          Text(err,
                              style: ctx.text.bodySmall
                                  ?.copyWith(color: mq.error)),
                        ],
                        const SizedBox(height: MqSpacing.xl),
                        MqButton(
                          label: submitting ? 'جارٍ الحفظ…' : 'حفظ',
                          icon: submitting ? null : Icons.check_rounded,
                          loading: submitting,
                          onPressed: submitting
                              ? null
                              : () async {
                                  if (title.text.trim().isEmpty) {
                                    setS(() => err = 'العنوان مطلوب');
                                    return;
                                  }
                                  setS(() {
                                    submitting = true;
                                    err = '';
                                  });
                                  try {
                                    await _api.updateVideoLesson(
                                      courseId: widget.courseId,
                                      lessonId: lesson['id'].toString(),
                                      title: title.text.trim(),
                                      description: description.text.trim(),
                                    );
                                    if (ctx.mounted) Navigator.pop(ctx, true);
                                  } catch (_) {
                                    setS(() {
                                      submitting = false;
                                      err = 'تعذّر الحفظ';
                                    });
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
    // Dispose after the sheet's slide-out animation; disposing while the
    // TextFields are still rebuilding crashes with "ChangeNotifier used after
    // dispose" (the red `_dependents.isEmpty` screen).
    Future.delayed(const Duration(milliseconds: 500), () {
      title.dispose();
      description.dispose();
    });
    if (ok == true) {
      _snack('تم تحديث الدرس.');
      _fetchAll();
    }
  }

  Future<void> _askDeleteLesson(Map<String, dynamic> lesson) async {
    final ok = await _confirmDialog(
      title: 'حذف الدرس',
      message: 'سيتم حذف الدرس وحذف الفيديو من Bunny.',
      confirmLabel: 'حذف',
      destructive: true,
    );
    if (ok != true) return;
    try {
      await _api.deleteVideoLesson(
        courseId: widget.courseId,
        lessonId: lesson['id'].toString(),
      );
      _snack('تم حذف الدرس.');
      _fetchAll();
    } catch (e) {
      _snack('تعذّر الحذف: $e', error: true);
    }
  }

  Future<void> _syncLesson(Map<String, dynamic> lesson) async {
    try {
      await _api.syncVideoLesson(
        courseId: widget.courseId,
        lessonId: lesson['id'].toString(),
      );
      _snack('تم تحديث حالة الدرس.');
      _fetchAll();
    } catch (e) {
      _snack('تعذّر التحديث: $e', error: true);
    }
  }

  void _moveLesson(int idx, int dir) {
    final target = idx + dir;
    if (target < 0 || target >= _lessons.length) return;
    setState(() {
      final tmp = _lessons[idx];
      _lessons[idx] = _lessons[target];
      _lessons[target] = tmp;
    });
  }

  Future<void> _saveReorder() async {
    setState(() => _reorderBusy = true);
    try {
      await _api.reorderVideoLessons(
        courseId: widget.courseId,
        lessonIds: _lessons.map((l) => l['id'].toString()).toList(),
      );
      _snack('تم حفظ الترتيب.');
      setState(() => _reorderMode = false);
      _fetchAll();
    } catch (e) {
      _snack('تعذّر حفظ الترتيب: $e', error: true);
    } finally {
      if (mounted) setState(() => _reorderBusy = false);
    }
  }

  void _playLesson(Map<String, dynamic> lesson) {
    if (lesson['bunnyStatus']?.toString() != 'ready') {
      _snack('الفيديو لم يكتمل المعالجة بعد. حاول بعد قليل.', error: true);
      return;
    }
    final url = lesson['bunnyPlaybackUrl']?.toString();
    if (url == null || url.isEmpty) {
      _snack('رابط التشغيل غير متوفر.', error: true);
      return;
    }
    Get.to(() => UnifiedVideoPlayerScreen(
          videoUrl: url,
          videoId: (lesson['id'] ?? url).toString(),
          title: lesson['title']?.toString() ?? 'درس',
          subtitle: _course?['title']?.toString(),
          thumbnailUrl: lesson['bunnyThumbnailUrl']?.toString(),
        ));
  }

  // ----- Helpers -----------------------------------------------------------

  Future<bool?> _confirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: Colors.red)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  void _snack(String text, {bool error = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red.shade700 : null,
        behavior: SnackBarBehavior.floating,
      ));
    });
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return iso;
    }
  }

  String _formatDuration(dynamic seconds) {
    final n = (seconds is num)
        ? seconds.toInt()
        : int.tryParse(seconds?.toString() ?? '0') ?? 0;
    if (n <= 0) return '—';
    final m = n ~/ 60;
    final s = n % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // ----- UI ----------------------------------------------------------------

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
              title: 'تفاصيل الدورة',
              actions: [
                if (!_loading && _course != null)
                  _ActionChip(
                      icon: Icons.edit_outlined, onTap: _openEditDialog),
                _ActionChip(
                    icon: Icons.refresh_rounded,
                    onTap: _loading ? null : _fetchAll),
              ],
            ),
            floatingActionButton: (_loading || _course == null || _reorderMode)
                ? null
                : FloatingActionButton(
                    onPressed: _openAddLessonDialog,
                    backgroundColor: mq.accent,
                    foregroundColor: mq.onAccent,
                    elevation: 3,
                    tooltip: 'درس جديد',
                    shape: const RoundedRectangleBorder(
                        borderRadius: MqRadius.brLg),
                    child: const Icon(Icons.add_rounded),
                  ),
            body: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? _ErrorState(message: _error, onRetry: _fetchAll)
                    : _course == null
                        ? Center(
                            child: Text('الدورة غير متوفرة',
                                style: context.text.bodyMedium))
                        : RefreshIndicator(
                            onRefresh: _fetchAll,
                            color: mq.accent,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(MqSpacing.lg,
                                  MqSpacing.lg, MqSpacing.lg, 96),
                              children: [
                                _summaryCard(context),
                                const SizedBox(height: MqSpacing.lg),
                                _lessonsHeader(context),
                                const SizedBox(height: MqSpacing.sm),
                                if (_lessons.isEmpty)
                                  _emptyLessons(context)
                                else
                                  _lessonsGrid(context),
                              ],
                            ),
                          ),
          );
        }),
      ),
    );
  }

  // ----- Summary card ------------------------------------------------------

  Widget _summaryCard(BuildContext context) {
    final mq = context.mq;
    final c = _course!;
    final (statusLabel, statusTone) =
        _courseStatus(c['status']?.toString() ?? '');
    final isFree = c['isFree'] == true;
    final isPublic = (c['visibility']?.toString() ?? 'private') == 'public';
    final desc = (c['description']?.toString() ?? '');
    final reviewNotes = (c['reviewNotes']?.toString() ?? '');

    return MqCard(
      padding: EdgeInsets.zero,
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
                    url: c['coverImage']?.toString() ?? '',
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.movie_outlined,
                  ),
                  if (_coverUploading)
                    Container(
                      color: Colors.black.withValues(alpha: 0.45),
                      alignment: Alignment.center,
                      child:
                          const CircularProgressIndicator(color: Colors.white),
                    ),
                  PositionedDirectional(
                    bottom: 8,
                    end: 8,
                    child: Material(
                      color: mq.card,
                      elevation: 2,
                      borderRadius: MqRadius.brPill,
                      child: InkWell(
                        borderRadius: MqRadius.brPill,
                        onTap: _coverUploading ? null : _changeCover,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: MqSpacing.md, vertical: MqSpacing.xs),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.image_outlined,
                                size: 16, color: mq.accent),
                            const SizedBox(width: MqSpacing.xs),
                            Text('غيّر الغلاف',
                                style: context.text.labelSmall?.copyWith(
                                    color: mq.accent,
                                    fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(MqSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(c['title']?.toString() ?? '',
                            style: context.text.titleMedium),
                      ),
                      _ActionChip(
                          icon: Icons.delete_outline_rounded,
                          color: mq.error,
                          onTap: _askDeleteCourse),
                    ],
                  ),
                  const SizedBox(height: MqSpacing.sm),
                  Wrap(
                    spacing: MqSpacing.xs,
                    runSpacing: MqSpacing.xs,
                    children: [
                      TeacherStatusPill(label: statusLabel, tone: statusTone),
                      MqBadge(
                          label: isPublic ? 'عامة' : 'خاصة',
                          tone: isPublic
                              ? MqBadgeTone.success
                              : MqBadgeTone.neutral),
                      MqBadge(
                          label: isFree ? 'مجاني' : '${fmtMoney(c['price'])} د.ع',
                          tone: isFree
                              ? MqBadgeTone.success
                              : MqBadgeTone.orange),
                    ],
                  ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: MqSpacing.md),
                    Text(desc,
                        style: context.text.bodySmall
                            ?.copyWith(color: mq.ink2, height: 1.5)),
                  ],
                  const SizedBox(height: MqSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: MqSpacing.md, vertical: MqSpacing.sm),
                    decoration: BoxDecoration(
                        color: mq.fill, borderRadius: MqRadius.brMd),
                    child: Column(
                      children: [
                        _metaRow(context, 'المادة',
                            c['subject']?.toString() ?? '—'),
                        _metaRow(context, 'المرحلة',
                            c['teachingStage']?.toString() ?? '—'),
                        _metaRow(context, 'الإضافة',
                            _formatDate(c['createdAt']?.toString())),
                        _metaRow(context, 'آخر تحديث',
                            _formatDate(c['updatedAt']?.toString())),
                      ],
                    ),
                  ),
                  if (reviewNotes.isNotEmpty) ...[
                    const SizedBox(height: MqSpacing.md),
                    MqSurface(
                      tone: MqSurfaceTone.orange,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ملاحظة من الإدارة',
                              style: context.text.labelSmall?.copyWith(
                                  color: context.teacher.warning,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: MqSpacing.xs),
                          Text(reviewNotes,
                              style: context.text.bodySmall
                                  ?.copyWith(height: 1.5)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaRow(BuildContext context, String label, String value) {
    final mq = context.mq;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(label,
                style: context.text.labelSmall?.copyWith(color: mq.ink3)),
          ),
          Expanded(
            child: Text(value,
                style: context.text.labelMedium
                    ?.copyWith(color: mq.ink, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ----- Lessons -----------------------------------------------------------

  Widget _lessonsHeader(BuildContext context) {
    return Row(
      children: [
        Text('الدروس', style: context.text.titleSmall),
        const SizedBox(width: MqSpacing.sm),
        MqBadge(label: '${_lessons.length}', tone: MqBadgeTone.accent),
        const Spacer(),
        if (!_reorderMode) ...[
          if (_lessons.length > 1)
            MqButton.text(
              label: 'ترتيب',
              icon: Icons.swap_vert_rounded,
              size: MqButtonSize.small,
              onPressed: () => setState(() => _reorderMode = true),
            ),
        ] else ...[
          MqButton.text(
            label: 'إلغاء',
            size: MqButtonSize.small,
            onPressed: _reorderBusy
                ? null
                : () {
                    setState(() => _reorderMode = false);
                    _fetchAll();
                  },
          ),
          const SizedBox(width: MqSpacing.xs),
          MqButton(
            label: 'حفظ',
            icon: _reorderBusy ? null : Icons.save_outlined,
            size: MqButtonSize.small,
            expand: false,
            loading: _reorderBusy,
            onPressed: _reorderBusy ? null : _saveReorder,
          ),
        ],
      ],
    );
  }

  Widget _emptyLessons(BuildContext context) {
    final mq = context.mq;
    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.xl),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: mq.fill2, shape: BoxShape.circle),
            child:
                Icon(Icons.movie_creation_outlined, size: 30, color: mq.ink3),
          ),
          const SizedBox(height: MqSpacing.md),
          Text('لم تضِف دروساً بعد',
              style: context.text.bodyMedium?.copyWith(color: mq.ink2)),
          const SizedBox(height: MqSpacing.md),
          MqButton.tonal(
            label: 'إضافة أول درس',
            icon: Icons.add_rounded,
            expand: false,
            onPressed: _openAddLessonDialog,
          ),
        ],
      ),
    );
  }

  Widget _lessonsGrid(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 256,
        crossAxisSpacing: MqSpacing.md,
        mainAxisSpacing: MqSpacing.md,
      ),
      itemCount: _lessons.length,
      itemBuilder: (_, idx) => _lessonCard(context, _lessons[idx], idx),
    );
  }

  Widget _lessonCard(BuildContext context, Map<String, dynamic> lesson, int idx) {
    final mq = context.mq;
    final bunny = lesson['bunnyStatus']?.toString() ?? '';
    final isReady = bunny == 'ready';
    final isProcessing = bunny == 'uploaded' || bunny == 'processing';
    final (label, tone) = _bunnyStatus(bunny);
    final hasDuration = (lesson['durationSeconds'] is num) &&
        (lesson['durationSeconds'] as num) > 0;

    return MqCard(
      padding: EdgeInsets.zero,
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
                    url: lesson['bunnyThumbnailUrl']?.toString() ?? '',
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.movie_outlined,
                  ),
                  PositionedDirectional(
                    top: 4,
                    start: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: MqSpacing.sm, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: MqRadius.brSm,
                      ),
                      child: Text('#${idx + 1}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                  if (hasDuration)
                    PositionedDirectional(
                      bottom: 4,
                      end: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: MqSpacing.sm, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: MqRadius.brSm,
                        ),
                        child: Text(_formatDuration(lesson['durationSeconds']),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10)),
                      ),
                    ),
                  if (isReady)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _playLesson(lesson),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.2),
                          alignment: Alignment.center,
                          child: const Icon(Icons.play_circle_filled,
                              color: Colors.white, size: 44),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  MqSpacing.sm, MqSpacing.sm, MqSpacing.sm, MqSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lesson['title']?.toString() ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: MqSpacing.xs),
                  TeacherStatusPill(label: label, tone: tone, dense: true),
                ],
              ),
            ),
            const Spacer(),
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: mq.line)),
              ),
              child: _reorderMode
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                          visualDensity: VisualDensity.compact,
                          color: mq.ink2,
                          onPressed:
                              idx == 0 ? null : () => _moveLesson(idx, -1),
                        ),
                        IconButton(
                          icon:
                              const Icon(Icons.arrow_downward_rounded, size: 18),
                          visualDensity: VisualDensity.compact,
                          color: mq.ink2,
                          onPressed: idx == _lessons.length - 1
                              ? null
                              : () => _moveLesson(idx, 1),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (isProcessing)
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            tooltip: 'تحديث الحالة',
                            visualDensity: VisualDensity.compact,
                            color: mq.ink2,
                            onPressed: () => _syncLesson(lesson),
                          ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'تعديل',
                          visualDensity: VisualDensity.compact,
                          color: mq.ink2,
                          onPressed: () => _openEditLessonDialog(lesson),
                        ),
                        IconButton(
                          icon: const Icon(Icons.upload_file_rounded, size: 18),
                          tooltip: 'استبدال الفيديو',
                          visualDensity: VisualDensity.compact,
                          color: mq.ink2,
                          onPressed: () => _replaceLessonVideo(lesson),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 18),
                          tooltip: 'حذف',
                          visualDensity: VisualDensity.compact,
                          color: mq.error,
                          onPressed: () => _askDeleteLesson(lesson),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.onTap, this.color});
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;

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
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: MqSize.iconSm, color: color ?? mq.ink2),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MqSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: mq.error),
            const SizedBox(height: MqSpacing.md),
            Text(message,
                textAlign: TextAlign.center, style: context.text.bodyMedium),
            const SizedBox(height: MqSpacing.lg),
            MqButton(
              label: 'إعادة المحاولة',
              icon: Icons.refresh_rounded,
              expand: false,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
