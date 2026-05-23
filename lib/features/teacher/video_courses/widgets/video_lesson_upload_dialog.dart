// Lesson upload dialog (create-new OR replace-existing).
//
// Single dialog that captures: title + description + a video file picked
// from the device + a "Upload" button. After the user taps Upload:
//   1. Backend mints a Bunny videoId + returns the upload contract.
//   2. We stream the file directly to Bunny with onSendProgress.
//   3. We hit /sync so the lesson card flips to processing/ready faster
//      than the webhook latency alone.
//   4. The dialog shows success / error inline — no native alerts.
//
// `replaceLessonId` toggles "replace" mode: on submit we delete the
// existing lesson + Bunny video and create fresh, then upload. Same
// dialog, same UX.
//
// Returns the new lesson id on success (so the caller can refresh /
// scroll to the new card).

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/teacher_api_service.dart';

class VideoLessonUploadDialog extends StatefulWidget {
  const VideoLessonUploadDialog({
    super.key,
    required this.courseId,
    this.replaceLessonId,
    this.initialTitle,
    this.initialDescription,
  });

  final String courseId;

  /// When set, the dialog runs in "replace" mode — submitting deletes the
  /// referenced lesson first then creates a new one.
  final String? replaceLessonId;
  final String? initialTitle;
  final String? initialDescription;

  bool get isReplace => replaceLessonId != null;

  @override
  State<VideoLessonUploadDialog> createState() => _VideoLessonUploadDialogState();
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
  String _phase = ''; // for status text shown beneath the progress bar

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initialTitle ?? '');
    _description = TextEditingController(text: widget.initialDescription ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
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
      setState(() {
        _file = f;
        _fileName = res.files.single.name;
        _fileSizeBytes = size;
        _error = '';
      });
    } catch (e) {
      setState(() => _error = 'تعذّر اختيار الملف: $e');
    }
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.isEmpty) { setState(() => _error = 'عنوان الدرس مطلوب'); return; }
    if (_file == null) { setState(() => _error = 'يرجى اختيار ملف الفيديو'); return; }

    setState(() {
      _submitting = true;
      _error = '';
      _progress = 0;
      _phase = 'تجهيز الدرس على الخادم…';
    });

    try {
      // Replace path: delete the OLD lesson first (best-effort). Failure
      // here doesn't block — the new lesson still gets created so the
      // user's intent ("ship a fresh video") is honored.
      if (widget.isReplace && widget.replaceLessonId != null) {
        try {
          await _api.deleteVideoLesson(
            courseId: widget.courseId,
            lessonId: widget.replaceLessonId!,
          );
        } catch (_) { /* keep going */ }
      }

      // 1) Create lesson — backend mints the Bunny videoId.
      final createRes = await _api.createVideoLesson(
        courseId: widget.courseId,
        title: title,
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
      );
      final data = (createRes['data'] is Map) ? Map<String, dynamic>.from(createRes['data']) : <String, dynamic>{};
      final lesson = (data['lesson'] is Map) ? Map<String, dynamic>.from(data['lesson']) : <String, dynamic>{};
      final upload = (data['upload'] is Map) ? Map<String, dynamic>.from(data['upload']) : <String, dynamic>{};
      final lessonId = lesson['id']?.toString();
      if (lessonId == null || upload['url'] == null) {
        throw Exception('استجابة الخادم غير صالحة');
      }

      // 2) Stream the file directly to Bunny.
      if (mounted) setState(() => _phase = 'رفع الفيديو إلى Bunny…');
      await _api.putToBunny(
        uploadContract: upload,
        filePath: _file!.path,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => _progress = p);
        },
      );

      // 3) Ask backend to reconcile so the lesson card flips faster.
      if (mounted) setState(() => _phase = 'تحديث حالة المعالجة…');
      try {
        await _api.syncVideoLesson(
          courseId: widget.courseId,
          lessonId: lessonId,
        );
      } catch (_) { /* webhook will eventually fix it */ }

      if (!mounted) return;
      setState(() {
        _success = true;
        _submitting = false;
        _phase = 'تم الرفع بنجاح. سيكتمل التحويل خلال دقائق.';
      });
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) Navigator.of(context).pop(lessonId);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = _humanizeError(e);
          _phase = '';
        });
      }
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
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.isReplace ? 'استبدال فيديو الدرس' : 'إضافة درس جديد'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _title,
              enabled: !_submitting,
              decoration: const InputDecoration(
                labelText: 'عنوان الدرس *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _description,
              maxLines: 2,
              enabled: !_submitting,
              decoration: const InputDecoration(
                labelText: 'الوصف (اختياري)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            // File picker / selected file display
            DottedTile(
              hasFile: _file != null,
              child: _file == null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_upload_outlined, color: scheme.primary, size: 32),
                        const SizedBox(height: 6),
                        const Text('اختر ملف الفيديو (MP4 يُفضّل)',
                            style: TextStyle(fontSize: 13)),
                        const SizedBox(height: 6),
                        OutlinedButton.icon(
                          onPressed: _submitting ? null : _pickFile,
                          icon: const Icon(Icons.folder_open, size: 16),
                          label: const Text('تصفّح…'),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.movie_outlined, color: scheme.primary, size: 28),
                        const SizedBox(height: 4),
                        Text(
                          _fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        Text('${_formatMB(_fileSizeBytes)} MB',
                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        if (!_submitting)
                          TextButton(
                            onPressed: () => setState(() {
                              _file = null;
                              _fileName = '';
                              _fileSizeBytes = 0;
                            }),
                            child: const Text('إزالة', style: TextStyle(color: Colors.redAccent)),
                          ),
                      ],
                    ),
            ),

            // Progress / phase / success / error
            if (_submitting && _progress > 0 && !_success) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _progress / 100,
                minHeight: 6,
                color: scheme.primary,
                backgroundColor: scheme.primary.withValues(alpha: 0.12),
              ),
              const SizedBox(height: 4),
              Center(child: Text('$_progress%', style: const TextStyle(fontSize: 12))),
            ],
            if (_phase.isNotEmpty) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _phase,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ),
            ],

            if (_success) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(children: const [
                  Icon(Icons.check_circle, color: Colors.green, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text('تم الرفع. جاري إغلاق النافذة…', style: TextStyle(fontSize: 12))),
                ]),
              ),
            ],
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(children: [
                  Icon(Icons.error_outline, color: scheme.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error, style: TextStyle(color: scheme.onErrorContainer, fontSize: 12))),
                ]),
              ),
            ],

            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.info_outline, size: 13, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'يمكنك إغلاق التطبيق بعد بدء الرفع — Bunny ستُكمل المعالجة',
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                ),
              ),
            ]),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(null),
          child: const Text('إغلاق'),
        ),
        FilledButton.icon(
          onPressed: (_submitting || _success) ? null : _submit,
          icon: _submitting
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.cloud_upload_outlined, size: 18),
          label: Text(_success ? 'تم' : 'رفع'),
        ),
      ],
    );
  }
}

/// Visual host for the "drag-or-pick" file area. Just a styled border.
class DottedTile extends StatelessWidget {
  const DottedTile({super.key, required this.hasFile, required this.child});
  final bool hasFile;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasFile
            ? scheme.primary.withValues(alpha: 0.06)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border.all(
          color: hasFile ? scheme.primary.withValues(alpha: 0.4) : scheme.outlineVariant,
          width: 1.5,
          style: hasFile ? BorderStyle.solid : BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}
