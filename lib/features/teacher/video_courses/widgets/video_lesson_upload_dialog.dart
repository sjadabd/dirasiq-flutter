// Lesson upload sheet (create-new OR replace-existing) — Teacher Design System.
//
// Captures: title + description + a video file + an "Upload" button. On submit:
//   1. Backend mints a Bunny videoId + returns the upload contract.
//   2. Stream the file directly to Bunny with onSendProgress.
//   3. Hit /sync so the lesson card flips to processing/ready faster.
//
// `replaceLessonId` toggles "replace" mode: on submit the existing lesson +
// Bunny video are deleted then a fresh one is created + uploaded.
//
// Presentation only — the file pick, the upload pipeline, the progress
// reporting, the replace flow, and the returned lesson id are UNCHANGED.
// Open with showModalBottomSheet<String?>(...).

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/teacher_api_service.dart';
import '../../shared/design/teacher_design.dart';

class VideoLessonUploadDialog extends StatefulWidget {
  const VideoLessonUploadDialog({
    super.key,
    required this.courseId,
    this.replaceLessonId,
    this.initialTitle,
    this.initialDescription,
  });

  final String courseId;
  final String? replaceLessonId;
  final String? initialTitle;
  final String? initialDescription;

  bool get isReplace => replaceLessonId != null;

  @override
  State<VideoLessonUploadDialog> createState() =>
      _VideoLessonUploadDialogState();
}

class _VideoLessonUploadDialogState extends State<VideoLessonUploadDialog> {
  final _api = TeacherApiService();
  late final TextEditingController _title;
  late final TextEditingController _description;

  File? _file;
  String _fileName = '';
  int _fileSizeBytes = 0;

  bool _submitting = false;
  bool _success = false;
  String _error = '';
  int _progress = 0;
  String _phase = '';

  bool _picking = false;
  bool _disposed = false;

  void _safeSetState(VoidCallback fn) {
    if (!mounted || _disposed) return;
    setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initialTitle ?? '');
    _description =
        TextEditingController(text: widget.initialDescription ?? '');
  }

  @override
  void dispose() {
    _disposed = true;
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    if (_picking) return;
    _picking = true;
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        withData: false,
      );
      if (res == null || res.files.isEmpty) return;
      final path = res.files.single.path;
      if (path == null) return;
      final f = File(path);
      final size = await f.length();
      _safeSetState(() {
        _file = f;
        _fileName = res.files.single.name;
        _fileSizeBytes = size;
        _error = '';
      });
    } catch (e) {
      _safeSetState(() => _error = 'تعذّر اختيار الملف: $e');
    } finally {
      _picking = false;
    }
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      _safeSetState(() => _error = 'عنوان الدرس مطلوب');
      return;
    }
    if (_file == null) {
      _safeSetState(() => _error = 'يرجى اختيار ملف الفيديو');
      return;
    }

    _safeSetState(() {
      _submitting = true;
      _error = '';
      _progress = 0;
      _phase = 'تجهيز الدرس على الخادم…';
    });

    try {
      if (widget.isReplace && widget.replaceLessonId != null) {
        try {
          await _api.deleteVideoLesson(
            courseId: widget.courseId,
            lessonId: widget.replaceLessonId!,
          );
        } catch (_) {/* keep going */}
      }

      final createRes = await _api.createVideoLesson(
        courseId: widget.courseId,
        title: title,
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
      );
      final data = (createRes['data'] is Map)
          ? Map<String, dynamic>.from(createRes['data'])
          : <String, dynamic>{};
      final lesson = (data['lesson'] is Map)
          ? Map<String, dynamic>.from(data['lesson'])
          : <String, dynamic>{};
      final upload = (data['upload'] is Map)
          ? Map<String, dynamic>.from(data['upload'])
          : <String, dynamic>{};
      final lessonId = lesson['id']?.toString();
      if (lessonId == null || upload['url'] == null) {
        throw Exception('استجابة الخادم غير صالحة');
      }

      _safeSetState(() => _phase = 'رفع الفيديو إلى Bunny…');
      await _api.putToBunny(
        uploadContract: upload,
        filePath: _file!.path,
        onProgress: (p) => _safeSetState(() => _progress = p),
      );

      _safeSetState(() => _phase = 'تحديث حالة المعالجة…');
      try {
        await _api.syncVideoLesson(
          courseId: widget.courseId,
          lessonId: lessonId,
        );
      } catch (_) {/* webhook will eventually fix it */}

      if (_disposed || !mounted) return;
      _safeSetState(() {
        _success = true;
        _submitting = false;
        _phase = 'تم الرفع بنجاح. سيكتمل التحويل خلال دقائق.';
      });
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!_disposed && mounted) Navigator.of(context).pop(lessonId);
      });
    } catch (e) {
      _safeSetState(() {
        _submitting = false;
        _error = _humanizeError(e);
        _phase = '';
      });
    }
  }

  String _humanizeError(Object e) {
    final msg = e.toString();
    if (msg.contains('DioException') || msg.contains('SocketException')) {
      return 'خطأ في الاتصال — تحقّق من الإنترنت ثم حاول مجدداً.';
    }
    return 'فشل الرفع. حاول مرة أخرى. (${msg.length > 80 ? '${msg.substring(0, 80)}…' : msg})';
  }

  String _formatMB(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: isDark ? MqTheme.dark() : MqTheme.light(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(builder: (context) {
          final mq = context.mq;
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.92),
              child: Container(
                decoration: BoxDecoration(
                  color: mq.card,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(MqRadius.xl)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _handle(context),
                      _header(context),
                      Flexible(child: _body(context)),
                      _saveBar(context),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _handle(BuildContext context) => Center(
        child: Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: MqSpacing.sm),
          decoration: BoxDecoration(
              color: context.mq.line, borderRadius: MqRadius.brPill),
        ),
      );

  Widget _header(BuildContext context) {
    final mq = context.mq;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          MqSpacing.lg, 0, MqSpacing.lg, MqSpacing.sm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration:
                BoxDecoration(color: mq.accentSoft, borderRadius: MqRadius.brSm),
            child: Icon(
                widget.isReplace
                    ? Icons.upload_file_rounded
                    : Icons.video_call_outlined,
                size: MqSize.iconSm,
                color: mq.accent),
          ),
          const SizedBox(width: MqSpacing.sm),
          Expanded(
            child: Text(
                widget.isReplace ? 'استبدال فيديو الدرس' : 'إضافة درس جديد',
                style: context.text.titleMedium),
          ),
          InkWell(
            onTap: _submitting ? null : () => Navigator.of(context).pop(null),
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, color: mq.ink3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final mq = context.mq;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          MqSpacing.lg, MqSpacing.sm, MqSpacing.lg, MqSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _title,
            enabled: !_submitting,
            decoration: const InputDecoration(
              labelText: 'عنوان الدرس *',
              prefixIcon: Icon(Icons.title_rounded),
              isDense: true,
            ),
          ),
          const SizedBox(height: MqSpacing.md),
          TextField(
            controller: _description,
            maxLines: 2,
            enabled: !_submitting,
            decoration: const InputDecoration(
              labelText: 'الوصف (اختياري)',
              hintText: 'وصف اختياري...',
            ),
          ),
          const SizedBox(height: MqSpacing.md),
          _filePicker(context),
          if (_submitting && _progress > 0 && !_success) ...[
            const SizedBox(height: MqSpacing.md),
            ClipRRect(
              borderRadius: MqRadius.brPill,
              child: LinearProgressIndicator(
                value: _progress / 100,
                minHeight: 7,
                color: mq.accent,
                backgroundColor: mq.fill2,
              ),
            ),
            const SizedBox(height: MqSpacing.xs),
            Center(
              child: Text('$_progress%',
                  style: MqTypography.mono(
                      color: mq.ink, size: 13, weight: FontWeight.w700)),
            ),
          ],
          if (_phase.isNotEmpty) ...[
            const SizedBox(height: MqSpacing.sm),
            Center(
              child: Text(_phase,
                  textAlign: TextAlign.center,
                  style: context.text.labelSmall?.copyWith(color: mq.ink2)),
            ),
          ],
          if (_success) ...[
            const SizedBox(height: MqSpacing.md),
            MqSurface(
              tone: MqSurfaceTone.success,
              child: Row(children: [
                Icon(Icons.check_circle_outline,
                    color: context.teacher.success, size: 18),
                const SizedBox(width: MqSpacing.sm),
                Expanded(
                  child: Text('تم الرفع. جاري إغلاق النافذة…',
                      style: context.text.bodySmall),
                ),
              ]),
            ),
          ],
          if (_error.isNotEmpty) ...[
            const SizedBox(height: MqSpacing.md),
            MqSurface(
              tone: MqSurfaceTone.neutral,
              child: Row(children: [
                Icon(Icons.error_outline_rounded, color: mq.error, size: 18),
                const SizedBox(width: MqSpacing.sm),
                Expanded(
                  child: Text(_error,
                      style: context.text.bodySmall?.copyWith(color: mq.error)),
                ),
              ]),
            ),
          ],
          const SizedBox(height: MqSpacing.md),
          Row(children: [
            Icon(Icons.info_outline_rounded, size: 14, color: mq.ink3),
            const SizedBox(width: MqSpacing.xs),
            Expanded(
              child: Text(
                'يمكنك إغلاق التطبيق بعد بدء الرفع — Bunny ستُكمل المعالجة',
                style: context.text.labelSmall?.copyWith(color: mq.ink3),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _filePicker(BuildContext context) {
    final mq = context.mq;
    final hasFile = _file != null;
    return Container(
      padding: const EdgeInsets.all(MqSpacing.lg),
      decoration: BoxDecoration(
        color: hasFile ? mq.accentSoft : mq.fill,
        border: Border.all(color: hasFile ? mq.accentLine : mq.line),
        borderRadius: MqRadius.brMd,
      ),
      child: _file == null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_upload_outlined, color: mq.accent, size: 32),
                const SizedBox(height: MqSpacing.xs),
                Text('اختر ملف الفيديو (MP4 يُفضّل)',
                    style: context.text.bodySmall?.copyWith(color: mq.ink2)),
                const SizedBox(height: MqSpacing.sm),
                MqButton.secondary(
                  label: 'تصفّح…',
                  icon: Icons.folder_open_outlined,
                  size: MqButtonSize.small,
                  expand: false,
                  onPressed: _submitting ? null : _pickFile,
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.movie_outlined, color: mq.accent, size: 28),
                const SizedBox(height: MqSpacing.xs),
                Text(_fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text('${_formatMB(_fileSizeBytes)} MB',
                    style: context.text.labelSmall?.copyWith(color: mq.ink3)),
                if (!_submitting)
                  MqButton.text(
                    label: 'إزالة',
                    size: MqButtonSize.small,
                    onPressed: () => _safeSetState(() {
                      _file = null;
                      _fileName = '';
                      _fileSizeBytes = 0;
                    }),
                  ),
              ],
            ),
    );
  }

  Widget _saveBar(BuildContext context) {
    final mq = context.mq;
    return Container(
      padding: const EdgeInsets.fromLTRB(
          MqSpacing.lg, MqSpacing.sm, MqSpacing.lg, MqSpacing.md),
      decoration: BoxDecoration(
        color: mq.card,
        border: Border(top: BorderSide(color: mq.line)),
      ),
      child: MqButton(
        label: _success
            ? 'تم'
            : _submitting
                ? 'جارٍ الرفع…'
                : 'رفع الفيديو',
        icon: (_submitting || _success) ? null : Icons.cloud_upload_outlined,
        loading: _submitting,
        onPressed: (_submitting || _success) ? null : _submit,
      ),
    );
  }
}
