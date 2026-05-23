// Teacher video-course detail (full screen).
//
// Read-only summary header (cover + title + status/visibility/price chips +
// metadata + review notes) with an Edit button → opens the shared form
// dialog. Below: lessons grid with thumbnail, Bunny status chip, and
// per-card action menu (play / edit-meta / replace-video / delete).
// Reorder mode swaps the action menu for up/down arrows + a "save order"
// button. Add-lesson FAB opens the lesson upload dialog.
//
// Every error / success surfaces inline (SnackBars + in-dialog alerts) —
// no native browser-style alerts.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/teacher_api_service.dart';
import '../../../shared/widgets/app_network_image.dart';
import 'widgets/hls_video_player_screen.dart';
import 'widgets/video_course_form_dialog.dart';
import 'widgets/video_lesson_upload_dialog.dart';

class TeacherVideoCourseDetailScreen extends StatefulWidget {
  const TeacherVideoCourseDetailScreen({super.key, required this.courseId});
  final String courseId;

  @override
  State<TeacherVideoCourseDetailScreen> createState() => _TeacherVideoCourseDetailScreenState();
}

class _TeacherVideoCourseDetailScreenState extends State<TeacherVideoCourseDetailScreen> {
  final _api = TeacherApiService();

  bool _loading = true;
  String _error = '';
  Map<String, dynamic>? _course;
  List<Map<String, dynamic>> _lessons = [];

  bool _coverUploading = false;
  bool _reorderMode = false;
  bool _reorderBusy = false;

  // Status chip mappings (matches the dashboard for consistency).
  static const _courseStatusMeta = <String, Map<String, dynamic>>{
    'pending_review': {'label': 'بانتظار المراجعة', 'color': Colors.orange,    'icon': Icons.access_time},
    'approved':       {'label': 'مقبولة',           'color': Colors.green,     'icon': Icons.check_circle_outline},
    'hidden':         {'label': 'مخفية',            'color': Colors.blueGrey,  'icon': Icons.visibility_off_outlined},
    'rejected':       {'label': 'مرفوضة',           'color': Colors.red,       'icon': Icons.cancel_outlined},
  };
  static const _bunnyStatusMeta = <String, Map<String, dynamic>>{
    'pending':    {'label': 'بانتظار الرفع',   'color': Colors.blueGrey, 'icon': Icons.schedule},
    'uploaded':   {'label': 'تم الرفع',        'color': Colors.blue,     'icon': Icons.cloud_done_outlined},
    'processing': {'label': 'قيد المعالجة',    'color': Colors.orange,   'icon': Icons.autorenew},
    'ready':      {'label': 'جاهز',            'color': Colors.green,    'icon': Icons.check_circle},
    'failed':     {'label': 'فشل',             'color': Colors.red,      'icon': Icons.error_outline},
  };

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() { _loading = true; _error = ''; });
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
    final id = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
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
      message: 'سيتم حذف الدورة وجميع دروسها. الإجراء غير قابل للاسترجاع من واجهة الأستاذ.',
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
    final newId = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
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
    final newId = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
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
    final title = TextEditingController(text: lesson['title']?.toString() ?? '');
    final description = TextEditingController(text: lesson['description']?.toString() ?? '');
    String err = '';
    bool submitting = false;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setS) {
          return AlertDialog(
            title: const Text('تعديل بيانات الدرس'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    enabled: !submitting,
                    decoration: const InputDecoration(
                      labelText: 'عنوان الدرس *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: description,
                    enabled: !submitting,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'الوصف',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  if (err.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(err, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: submitting
                    ? null
                    : () async {
                        if (title.text.trim().isEmpty) {
                          setS(() => err = 'العنوان مطلوب');
                          return;
                        }
                        setS(() { submitting = true; err = ''; });
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
                child: submitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('حفظ'),
              ),
            ],
          );
        });
      },
    );
    title.dispose();
    description.dispose();
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
    Get.to(() => HlsVideoPlayerScreen(
          url: url,
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: destructive ? FilledButton.styleFrom(backgroundColor: Colors.red) : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  void _snack(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? Colors.red.shade700 : null,
      behavior: SnackBarBehavior.floating,
    ));
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
    final n = (seconds is num) ? seconds.toInt() : int.tryParse(seconds?.toString() ?? '0') ?? 0;
    if (n <= 0) return '—';
    final m = n ~/ 60;
    final s = n % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // ----- UI ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        title: Text(_course?['title']?.toString() ?? 'تفاصيل الدورة',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (!_loading && _course != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'تعديل',
              onPressed: _openEditDialog,
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _loading ? null : _fetchAll,
          ),
        ],
      ),
      floatingActionButton: (_loading || _course == null || _reorderMode)
          ? null
          : FloatingActionButton.extended(
              onPressed: _openAddLessonDialog,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('درس جديد'),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? _ErrorState(message: _error, onRetry: _fetchAll)
              : _course == null
                  ? const Center(child: Text('الدورة غير متوفرة'))
                  : RefreshIndicator(
                      onRefresh: _fetchAll,
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          _buildSummaryCard(scheme),
                          const SizedBox(height: 12),
                          _buildLessonsHeader(scheme),
                          const SizedBox(height: 8),
                          if (_lessons.isEmpty)
                            _buildEmptyLessons()
                          else
                            _buildLessonsGrid(scheme),
                          const SizedBox(height: 100), // bottom padding for FAB
                        ],
                      ),
                    ),
    );
  }

  // ----- Summary card ------------------------------------------------------

  Widget _buildSummaryCard(ColorScheme scheme) {
    final c = _course!;
    final statusKey = c['status']?.toString() ?? '';
    final statusMeta = _courseStatusMeta[statusKey] ?? {
      'label': statusKey, 'color': Colors.grey, 'icon': Icons.help_outline,
    };
    final isFree = c['isFree'] == true;
    final visibility = c['visibility']?.toString() ?? 'private';
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
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
                    child: const CircularProgressIndicator(color: Colors.white),
                  ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: ElevatedButton.icon(
                    onPressed: _coverUploading ? null : _changeCover,
                    icon: const Icon(Icons.image_outlined, size: 16),
                    label: const Text('غيّر الغلاف', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: scheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        c['title']?.toString() ?? '',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'حذف الدورة',
                      onPressed: _askDeleteCourse,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _chip(statusMeta['label'] as String, statusMeta['color'] as Color, icon: statusMeta['icon'] as IconData),
                  _chip(visibility == 'public' ? 'عامة' : 'خاصة', visibility == 'public' ? Colors.green : Colors.blueGrey),
                  _chip(isFree ? 'مجاني' : '${c['price'] ?? 0} د.ع', isFree ? Colors.green : Colors.orange),
                ]),
                if ((c['description']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(c['description'].toString(),
                      style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.85), height: 1.5)),
                ],
                const SizedBox(height: 12),
                _metaRow('المادة', c['subject']?.toString() ?? '—'),
                _metaRow('المرحلة', c['teachingStage']?.toString() ?? '—'),
                _metaRow('الإضافة', _formatDate(c['createdAt']?.toString())),
                _metaRow('آخر تحديث', _formatDate(c['updatedAt']?.toString())),
                if ((c['reviewNotes']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('ملاحظة من الإدارة',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.orange)),
                      const SizedBox(height: 4),
                      Text(c['reviewNotes'].toString(),
                          style: const TextStyle(fontSize: 13, height: 1.5)),
                    ]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 80,
          child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }

  Widget _chip(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
        ],
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  // ----- Lessons -----------------------------------------------------------

  Widget _buildLessonsHeader(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(children: [
        const Text('الدروس', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(width: 6),
        _chip('${_lessons.length}', scheme.primary),
        const Spacer(),
        if (!_reorderMode) ...[
          if (_lessons.length > 1)
            TextButton.icon(
              onPressed: () => setState(() => _reorderMode = true),
              icon: const Icon(Icons.swap_vert, size: 16),
              label: const Text('ترتيب'),
            ),
        ] else ...[
          TextButton(onPressed: _reorderBusy ? null : () { setState(() => _reorderMode = false); _fetchAll(); }, child: const Text('إلغاء')),
          FilledButton.icon(
            onPressed: _reorderBusy ? null : _saveReorder,
            icon: _reorderBusy
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save, size: 16),
            label: const Text('حفظ'),
          ),
        ],
      ]),
    );
  }

  Widget _buildEmptyLessons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3), style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: [
        const Icon(Icons.movie_creation_outlined, size: 40, color: Colors.grey),
        const SizedBox(height: 8),
        const Text('لم تضِف دروساً بعد', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: _openAddLessonDialog,
          icon: const Icon(Icons.add),
          label: const Text('إضافة أول درس'),
        ),
      ]),
    );
  }

  Widget _buildLessonsGrid(ColorScheme scheme) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 250,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _lessons.length,
      itemBuilder: (_, idx) => _buildLessonCard(scheme, _lessons[idx], idx),
    );
  }

  Widget _buildLessonCard(ColorScheme scheme, Map<String, dynamic> lesson, int idx) {
    final bunnyStatus = lesson['bunnyStatus']?.toString() ?? '';
    final isReady = bunnyStatus == 'ready';
    final isProcessing = bunnyStatus == 'uploaded' || bunnyStatus == 'processing';
    final meta = _bunnyStatusMeta[bunnyStatus] ?? {
      'label': bunnyStatus, 'color': Colors.grey, 'icon': Icons.help_outline,
    };
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thumb + play overlay
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
                Positioned(
                  top: 4, left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('#${idx + 1}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ),
                if ((lesson['durationSeconds'] is num) && (lesson['durationSeconds'] as num) > 0)
                  Positioned(
                    bottom: 4, right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(_formatDuration(lesson['durationSeconds']),
                          style: const TextStyle(color: Colors.white, fontSize: 10)),
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
                        child: const Icon(Icons.play_circle_filled, color: Colors.white, size: 44),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lesson['title']?.toString() ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                _chip(meta['label'] as String, meta['color'] as Color, icon: meta['icon'] as IconData),
              ],
            ),
          ),
          const Spacer(),
          // Action bar
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5))),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: _reorderMode
                ? Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_upward, size: 18),
                      tooltip: 'تحريك لأعلى',
                      visualDensity: VisualDensity.compact,
                      onPressed: idx == 0 ? null : () => _moveLesson(idx, -1),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_downward, size: 18),
                      tooltip: 'تحريك لأسفل',
                      visualDensity: VisualDensity.compact,
                      onPressed: idx == _lessons.length - 1 ? null : () => _moveLesson(idx, 1),
                    ),
                  ])
                : Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    if (isProcessing)
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 18),
                        tooltip: 'تحديث الحالة',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _syncLesson(lesson),
                      ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'تعديل البيانات',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _openEditLessonDialog(lesson),
                    ),
                    IconButton(
                      icon: const Icon(Icons.upload_file, size: 18),
                      tooltip: 'استبدال الفيديو',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _replaceLessonVideo(lesson),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      tooltip: 'حذف',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _askDeleteLesson(lesson),
                    ),
                  ]),
          ),
        ],
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
