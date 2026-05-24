// Shared create/edit dialog for video courses.
//
// Single component used by:
//   - list screen → create new course (returns the new course id)
//   - detail screen → edit existing course (returns true on success)
//
// Dropdowns for subject + teachingStage are sourced from the teacher's
// OWN subjects + grades (per product constraint — no free-text). Catalogs
// load synchronously inside the dialog; while loading the dialog shows a
// spinner instead of empty disabled dropdowns to avoid confusing UX.
//
// Cover image is a 2-step server flow (the backend `cover-image` endpoint
// is POST /:id/cover-image, so the row must exist first). The dialog hides
// that: it creates/updates the course first, then if the user picked a
// file it uploads it as a follow-up call before resolving. A failed cover
// upload doesn't roll back the course — the user keeps the new course and
// gets a snackbar-grade error on the next screen via the standard
// change-cover button.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/teacher_api_service.dart';
import '../../../../core/utils/content_url.dart';

class VideoCourseFormDialog extends StatefulWidget {
  const VideoCourseFormDialog({super.key, this.initial});

  /// When non-null, the dialog opens in EDIT mode pre-filled with these
  /// values. Required field on a course row: `id`.
  final Map<String, dynamic>? initial;

  bool get isEdit => initial != null && (initial!['id']?.toString().isNotEmpty ?? false);

  @override
  State<VideoCourseFormDialog> createState() => _VideoCourseFormDialogState();
}

class _VideoCourseFormDialogState extends State<VideoCourseFormDialog> {
  final _api = TeacherApiService();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController(text: '0');

  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _grades = [];
  bool _loadingCatalogs = true;
  String? _selectedSubject;
  String? _selectedGradeId;
  String _selectedGradeName = '';

  bool _isFree = true;
  String _visibility = 'private';

  bool _submitting = false;
  String _error = '';

  // ----- Cover image ------------------------------------------------------
  // _coverFile is set when the user picks a NEW image. Existing courses
  // (edit mode) carry their persisted cover under initial['coverImage'] —
  // we render that as the fallback preview when no new file is picked.
  File? _coverFile;
  String _coverFileName = '';
  bool _pickingCover = false;
  String _coverPhase = ''; // status text shown during the upload step

  String get _existingCoverUrl {
    final raw = widget.initial?['coverImage']?.toString();
    if (raw == null || raw.isEmpty) return '';
    return resolveContentUrl(raw);
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _title.text = initial['title']?.toString() ?? '';
      _description.text = initial['description']?.toString() ?? '';
      _selectedSubject = initial['subject']?.toString();
      _selectedGradeId = initial['gradeId']?.toString();
      _selectedGradeName = initial['teachingStage']?.toString() ?? '';
      _isFree = initial['isFree'] == true;
      final p = initial['price'];
      _price.text = (p is num ? p.toInt() : int.tryParse(p?.toString() ?? '0') ?? 0).toString();
      _visibility = (initial['visibility']?.toString() ?? 'private');
    }
    _loadCatalogs();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _loadCatalogs() async {
    try {
      final results = await Future.wait([
        _api.fetchMySubjectsCatalog(),
        _api.fetchMyGradesCatalog(),
      ]);
      if (!mounted) return;
      setState(() {
        _subjects = results[0];
        _grades = results[1];
        _loadingCatalogs = false;
        // For EDIT mode: if the persisted subject / grade isn't in the
        // catalog (e.g. teacher removed the subject after the course was
        // created), clear the selection so the dropdown doesn't render
        // an invalid value.
        if (_selectedSubject != null &&
            !_subjects.any((s) => _subjectValue(s) == _selectedSubject)) {
          // keep the value so it still saves on submit — Dropdown will
          // just show empty until user picks something
        }
        if (_selectedGradeId != null &&
            !_grades.any((g) => _gradeUuid(g) == _selectedGradeId)) {
          // same — don't auto-clear so we don't surprise the teacher
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCatalogs = false);
    }
  }

  String _subjectValue(Map s) {
    return (s['name'] ?? s['title'] ?? s['subject'])?.toString() ?? '';
  }

  String _gradeName(Map g) {
    return (g['name'] ?? g['gradeName'] ?? g['title'])?.toString() ?? '';
  }

  /// Extract the REAL grade UUID from a /grades/my-grades row.
  ///
  /// The endpoint returns junction-table rows shaped as:
  ///   `{ id: <teacher_grades.id>, gradeId: <grades.id>, gradeName: ..., ... }`
  /// We need the `gradeId` field — NOT `id` — because `id` is the junction
  /// row's UUID which doesn't exist in the `grades` table. Sending it as
  /// `gradeId` to /api/teacher/video-courses causes Postgres FK violations
  /// → HTTP 500 (this was the bug fixed in this commit).
  ///
  /// Falls back to `id` only if `gradeId` is missing — happens when the
  /// API ever changes to return raw grades.
  String _gradeUuid(Map g) {
    final viaGradeId = g['gradeId']?.toString();
    if (viaGradeId != null && viaGradeId.isNotEmpty) return viaGradeId;
    return g['id']?.toString() ?? '';
  }

  /// Pick a cover image. Guarded by [_pickingCover] against the same
  /// PlatformException(already_active) race that bit the lesson upload
  /// dialog when the user double-taps "browse" before the native picker
  /// dialog mounts.
  Future<void> _pickCover() async {
    if (_pickingCover) return;
    _pickingCover = true;
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        allowMultiple: false,
        withData: false,
      );
      if (res == null || res.files.isEmpty) return;
      final path = res.files.single.path;
      if (path == null) return;
      if (!mounted) return;
      setState(() {
        _coverFile = File(path);
        _coverFileName = res.files.single.name;
        _error = '';
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذّر اختيار صورة الغلاف: $e');
    } finally {
      _pickingCover = false;
    }
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.isEmpty) { setState(() => _error = 'العنوان مطلوب'); return; }
    if ((_selectedSubject ?? '').isEmpty) { setState(() => _error = 'يجب اختيار المادة'); return; }
    if ((_selectedGradeId ?? '').isEmpty || _selectedGradeName.isEmpty) {
      setState(() => _error = 'يجب اختيار المرحلة'); return;
    }
    setState(() { _submitting = true; _error = ''; _coverPhase = ''; });
    try {
      final payload = <String, dynamic>{
        'title': title,
        'subject': _selectedSubject,
        'teachingStage': _selectedGradeName,
        'gradeId': _selectedGradeId,
        'isFree': _isFree,
        'price': _isFree ? 0 : (int.tryParse(_price.text.trim()) ?? 0),
        'visibility': _visibility,
      };
      if (_description.text.trim().isNotEmpty) {
        payload['description'] = _description.text.trim();
      }

      String courseId;
      if (widget.isEdit) {
        courseId = widget.initial!['id'].toString();
        await _api.updateVideoCourse(courseId, payload);
      } else {
        final res = await _api.createVideoCourse(payload);
        final id = res['data']?['course']?['id']?.toString();
        if (id == null || id.isEmpty) {
          throw Exception('استجابة الخادم غير صالحة (لا يوجد معرّف الدورة)');
        }
        courseId = id;
      }

      // Cover upload step. The course already exists at this point, so a
      // failure here does NOT roll back — we leave the row in place and
      // surface a non-fatal error so the user can retry from the detail
      // screen via the standard change-cover button.
      if (_coverFile != null) {
        if (mounted) setState(() => _coverPhase = 'رفع صورة الغلاف…');
        try {
          await _api.uploadVideoCourseCoverImage(courseId, _coverFile!.path);
        } catch (e) {
          if (mounted) {
            setState(() {
              _error = widget.isEdit
                  ? 'تم حفظ التعديلات لكن تعذّر رفع الغلاف — جرّب من زر تغيير الغلاف.'
                  : 'تم إنشاء الدورة لكن تعذّر رفع الغلاف — جرّب من زر تغيير الغلاف.';
              _coverPhase = '';
              _submitting = false;
            });
          }
          // Still pop with the id so the caller refreshes / navigates.
          if (mounted) Navigator.of(context).pop(courseId);
          return;
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(courseId);
    } catch (e) {
      if (mounted) setState(() => _error = widget.isEdit ? 'تعذّر حفظ التعديلات' : 'تعذّر إنشاء الدورة');
    } finally {
      if (mounted) setState(() { _submitting = false; _coverPhase = ''; });
    }
  }

  /// Cover preview + browse + remove. Three states:
  ///   - new file picked → show File preview + "تغيير" + "إزالة"
  ///   - edit mode with existing remote cover → show network preview +
  ///     "تغيير" (no remove — there's no API to clear it; the user can
  ///     only replace)
  ///   - empty → dotted placeholder + "تصفّح"
  Widget _buildCoverField(ColorScheme scheme) {
    final hasNew = _coverFile != null;
    final existingUrl = _existingCoverUrl;
    final hasExisting = existingUrl.isNotEmpty;
    final disabled = _submitting;

    // NOTE: width must NOT be `double.infinity` on any child here.
    // AlertDialog wraps its content area in IntrinsicWidth to size itself,
    // and IntrinsicWidth asserts that every descendant's intrinsic width is
    // finite. `Image(width: double.infinity)` returns infinity → assertion
    // fails ("input.isFinite"). The fix is to let the OUTER stretch (the
    // dialog content Column has `crossAxisAlignment: stretch`) plus the
    // Container's `clipBehavior` give us the visible width, while the
    // children stay intrinsic-width-friendly (finite or zero).
    Widget preview;
    if (hasNew) {
      preview = Image.file(_coverFile!, fit: BoxFit.cover, height: 120);
    } else if (hasExisting) {
      preview = Image.network(
        existingUrl,
        fit: BoxFit.cover,
        height: 120,
        errorBuilder: (ctx, err, stack) => _coverPlaceholder(scheme, label: 'تعذّر تحميل المعاينة'),
      );
    } else {
      preview = _coverPlaceholder(scheme);
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          preview,
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Row(
              children: [
                Icon(Icons.image_outlined, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hasNew
                        ? _coverFileName
                        : (hasExisting ? 'الغلاف الحالي' : 'صورة الغلاف (اختياري)'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ),
                if (hasNew)
                  TextButton(
                    onPressed: disabled ? null : () => setState(() {
                      _coverFile = null;
                      _coverFileName = '';
                    }),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('إزالة', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
                TextButton.icon(
                  onPressed: disabled ? null : _pickCover,
                  icon: const Icon(Icons.folder_open, size: 14),
                  label: Text(hasNew || hasExisting ? 'تغيير' : 'تصفّح', style: const TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverPlaceholder(ColorScheme scheme, {String? label}) {
    // Same constraint as the Image branches: NO `width: double.infinity`
    // anywhere — the outer stretch + clipBehavior handles the visible
    // width; this child only needs to declare a finite height.
    return Container(
      height: 120,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, color: scheme.onSurfaceVariant, size: 28),
            const SizedBox(height: 4),
            Text(
              label ?? 'لا توجد صورة — JPG / PNG / WEBP حتى 5MB',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isEdit = widget.isEdit;
    if (_loadingCatalogs) {
      return AlertDialog(
        title: Text(isEdit ? 'تعديل الدورة' : 'إنشاء دورة مرئية جديدة'),
        content: const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final hint = _subjects.isEmpty && _grades.isEmpty
        ? 'لم تضِف بعد مواد أو مراحل. أضِفها من قسم المواد والمراحل قبل إنشاء دورة.'
        : _subjects.isEmpty
            ? 'أضِف مادة على الأقل قبل إنشاء دورة.'
            : _grades.isEmpty
                ? 'أضِف مرحلة على الأقل قبل إنشاء دورة.'
                : '';

    return AlertDialog(
      title: Text(isEdit ? 'تعديل الدورة' : 'إنشاء دورة مرئية جديدة'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hint.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(hint, style: const TextStyle(fontSize: 12)),
              ),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'عنوان الدورة *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _description,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'الوصف',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            _buildCoverField(scheme),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedSubject != null && _subjects.any((s) => _subjectValue(s) == _selectedSubject)
                  ? _selectedSubject
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'المادة *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _subjects
                  .map((s) {
                    final v = _subjectValue(s);
                    if (v.isEmpty) return null;
                    return DropdownMenuItem<String>(value: v, child: Text(v));
                  })
                  .whereType<DropdownMenuItem<String>>()
                  .toList(),
              onChanged: _subjects.isEmpty ? null : (v) => setState(() => _selectedSubject = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedGradeId != null && _grades.any((g) => _gradeUuid(g) == _selectedGradeId)
                  ? _selectedGradeId
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'المرحلة *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _grades
                  .map((g) {
                    final uuid = _gradeUuid(g);
                    final name = _gradeName(g);
                    if (uuid.isEmpty || name.isEmpty) return null;
                    return DropdownMenuItem<String>(value: uuid, child: Text(name));
                  })
                  .whereType<DropdownMenuItem<String>>()
                  .toList(),
              onChanged: _grades.isEmpty ? null : (v) {
                final g = _grades.firstWhere((g) => _gradeUuid(g) == v, orElse: () => {});
                setState(() {
                  _selectedGradeId = v;
                  _selectedGradeName = _gradeName(g);
                });
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('مجاني'),
              value: _isFree,
              onChanged: (v) => setState(() => _isFree = v),
            ),
            if (!_isFree)
              TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'السعر (د.ع)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _visibility,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'الرؤية',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'private', child: Text('خاصة')),
                DropdownMenuItem(value: 'public',  child: Text('عامة')),
              ],
              onChanged: (v) => setState(() => _visibility = v ?? 'private'),
            ),
            if (isEdit) ...[
              const SizedBox(height: 8),
              Text(
                '* أي تعديل يعيد الدورة إلى حالة "بانتظار المراجعة" من قبل الإدارة.',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
            if (_coverPhase.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(children: [
                  const SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(_coverPhase, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ]),
              ),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error, style: TextStyle(color: scheme.error, fontSize: 12)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, null),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: (_submitting || _subjects.isEmpty || _grades.isEmpty) ? null : _submit,
          child: _submitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(isEdit ? 'حفظ' : 'إنشاء'),
        ),
      ],
    );
  }
}
