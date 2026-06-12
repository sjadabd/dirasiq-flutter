// Shared create/edit sheet for video courses (Teacher Design System pass).
//
// Single component used by:
//   - list screen → create new course (returns the new course id)
//   - detail screen → edit existing course (returns the id on success)
//
// Presentation only — the catalog loading, subject/grade dropdowns (with the
// FK-safe `gradeId` extraction), the two-step cover-image upload, and the
// create/update submit are UNCHANGED. Restyled from an AlertDialog to an
// animated design-system bottom sheet. Open with:
//   showModalBottomSheet<String?>(... builder: (_) => const VideoCourseFormDialog())

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/teacher_api_service.dart';
import '../../../../core/utils/content_url.dart';
import '../../shared/design/teacher_design.dart';

class VideoCourseFormDialog extends StatefulWidget {
  const VideoCourseFormDialog({super.key, this.initial});

  final Map<String, dynamic>? initial;

  bool get isEdit =>
      initial != null && (initial!['id']?.toString().isNotEmpty ?? false);

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

  // Access model (backend: video_courses.access_type). 'enrolled_students_free'
  // links the video course to in-person courses (video_course_target_courses)
  // so their enrolled students get it free.
  String _accessType = 'public_free_by_grade';
  List<Map<String, dynamic>> _liveCourses = []; // teacher's in-person courses
  final Set<String> _targetCourseIds = {}; // selected linked in-person courses

  bool _submitting = false;
  String _error = '';

  static const _accessTypes = <(String, String)>[
    ('public_free_by_grade', 'مجاني — لطلاب المرحلة'),
    ('enrolled_students_free', 'مجاني — لطلاب كورس حضوري'),
    ('marketplace_paid', 'مدفوع'),
  ];

  File? _coverFile;
  String _coverFileName = '';
  bool _pickingCover = false;
  String _coverPhase = '';

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
      _price.text =
          (p is num ? p.toInt() : int.tryParse(p?.toString() ?? '0') ?? 0)
              .toString();
      _visibility = (initial['visibility']?.toString() ?? 'private');
      final at = initial['accessType']?.toString();
      _accessType = _accessTypes.any((e) => e.$1 == at)
          ? at!
          : (_isFree ? 'public_free_by_grade' : 'marketplace_paid');
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
        _api.fetchCourseNames(), // teacher's in-person courses (id + course_name)
      ]);
      final courses = _listOf(results[2] as Map<String, dynamic>);
      // In edit mode, prefill the currently-linked in-person courses.
      if (widget.isEdit) {
        try {
          final detail =
              await _api.fetchMyVideoCourse(widget.initial!['id'].toString());
          final data = (detail['data'] is Map)
              ? Map<String, dynamic>.from(detail['data'])
              : const {};
          final tc = data['targetCourses'];
          if (tc is List) {
            for (final e in tc) {
              if (e is Map) {
                final id = (e['courseId'] ?? e['course_id'] ?? '').toString();
                if (id.isNotEmpty) _targetCourseIds.add(id);
              }
            }
          }
        } catch (_) {/* non-fatal — teacher can re-select */}
      }
      if (!mounted) return;
      setState(() {
        _subjects = results[0] as List<Map<String, dynamic>>;
        _grades = results[1] as List<Map<String, dynamic>>;
        _liveCourses = courses;
        _loadingCatalogs = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCatalogs = false);
    }
  }

  List<Map<String, dynamic>> _listOf(Map<String, dynamic> res) {
    final d = res['data'];
    if (d is List) {
      return d.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    }
    if (d is Map && d['items'] is List) {
      return (d['items'] as List)
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return const [];
  }

  String _subjectValue(Map s) =>
      (s['name'] ?? s['title'] ?? s['subject'])?.toString() ?? '';

  String _gradeName(Map g) =>
      (g['name'] ?? g['gradeName'] ?? g['title'])?.toString() ?? '';

  /// Extract the REAL grade UUID — the `gradeId` field, not the junction
  /// row's `id` (sending `id` causes an FK violation server-side).
  String _gradeUuid(Map g) {
    final viaGradeId = g['gradeId']?.toString();
    if (viaGradeId != null && viaGradeId.isNotEmpty) return viaGradeId;
    return g['id']?.toString() ?? '';
  }

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
    if (title.isEmpty) {
      setState(() => _error = 'العنوان مطلوب');
      return;
    }
    if ((_selectedSubject ?? '').isEmpty) {
      setState(() => _error = 'يجب اختيار المادة');
      return;
    }
    if ((_selectedGradeId ?? '').isEmpty || _selectedGradeName.isEmpty) {
      setState(() => _error = 'يجب اختيار المرحلة');
      return;
    }
    if (_accessType == 'enrolled_students_free' && _targetCourseIds.isEmpty) {
      setState(() => _error = 'اختر كورساً حضورياً واحداً على الأقل للربط');
      return;
    }
    final price = int.tryParse(_price.text.trim()) ?? 0;
    if (_accessType == 'marketplace_paid' && price <= 0) {
      setState(() => _error = 'أدخل سعراً أكبر من 0 للكورس المدفوع');
      return;
    }
    setState(() {
      _submitting = true;
      _error = '';
      _coverPhase = '';
    });
    try {
      final paid = _accessType == 'marketplace_paid';
      final payload = <String, dynamic>{
        'title': title,
        'subject': _selectedSubject,
        'teachingStage': _selectedGradeName,
        'gradeId': _selectedGradeId,
        'visibility': _visibility,
        'accessType': _accessType,
        if (_accessType == 'public_free_by_grade' || paid)
          'gradeTargetIds': [_selectedGradeId],
        if (_accessType == 'enrolled_students_free')
          'targetCourseIds': _targetCourseIds.toList(),
        if (paid) 'priceIqd': price,
        // legacy back-compat (service back-fills from accessType anyway):
        'isFree': !paid,
        'price': paid ? price : 0,
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
          if (mounted) Navigator.of(context).pop(courseId);
          return;
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(courseId);
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = widget.isEdit ? 'تعذّر حفظ التعديلات' : 'تعذّر إنشاء الدورة');
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _coverPhase = '';
        });
      }
    }
  }

  // ---------------------------------------------------------------------------

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
                      Flexible(
                        child: _loadingCatalogs
                            ? const Padding(
                                padding: EdgeInsets.all(MqSpacing.xxl),
                                child:
                                    Center(child: CircularProgressIndicator()),
                              )
                            : _formBody(context),
                      ),
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
      padding:
          const EdgeInsets.fromLTRB(MqSpacing.lg, 0, MqSpacing.lg, MqSpacing.sm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration:
                BoxDecoration(color: mq.accentSoft, borderRadius: MqRadius.brSm),
            child: Icon(widget.isEdit ? Icons.edit_outlined : Icons.add_rounded,
                size: MqSize.iconSm, color: mq.accent),
          ),
          const SizedBox(width: MqSpacing.sm),
          Expanded(
            child: Text(
                widget.isEdit ? 'تعديل الدورة' : 'إنشاء دورة مرئية جديدة',
                style: context.text.titleMedium),
          ),
          InkWell(
            onTap: () => Navigator.of(context).pop(null),
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

  Widget _formBody(BuildContext context) {
    final mq = context.mq;
    final hint = _subjects.isEmpty && _grades.isEmpty
        ? 'لم تضِف بعد مواد أو مراحل. أضِفها قبل إنشاء دورة.'
        : _subjects.isEmpty
            ? 'أضِف مادة على الأقل قبل إنشاء دورة.'
            : _grades.isEmpty
                ? 'أضِف مرحلة على الأقل قبل إنشاء دورة.'
                : '';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          MqSpacing.lg, MqSpacing.sm, MqSpacing.lg, MqSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hint.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: MqSpacing.md),
              child: MqSurface(
                tone: MqSurfaceTone.orange,
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 18, color: mq.orangeDeep),
                    const SizedBox(width: MqSpacing.sm),
                    Expanded(
                      child: Text(hint,
                          style:
                              context.text.bodySmall?.copyWith(color: mq.ink2)),
                    ),
                  ],
                ),
              ),
            ),
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'عنوان الدورة *',
              prefixIcon: Icon(Icons.video_library_outlined),
              isDense: true,
            ),
          ),
          const SizedBox(height: MqSpacing.md),
          TextField(
            controller: _description,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'الوصف',
              hintText: 'وصف اختياري...',
            ),
          ),
          const SizedBox(height: MqSpacing.md),
          _coverField(context),
          const SizedBox(height: MqSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _selectedSubject != null &&
                    _subjects.any((s) => _subjectValue(s) == _selectedSubject)
                ? _selectedSubject
                : null,
            isExpanded: true,
            dropdownColor: mq.card,
            decoration: const InputDecoration(
              labelText: 'المادة *',
              prefixIcon: Icon(Icons.menu_book_outlined),
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
            onChanged: _subjects.isEmpty
                ? null
                : (v) => setState(() => _selectedSubject = v),
          ),
          const SizedBox(height: MqSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _selectedGradeId != null &&
                    _grades.any((g) => _gradeUuid(g) == _selectedGradeId)
                ? _selectedGradeId
                : null,
            isExpanded: true,
            dropdownColor: mq.card,
            decoration: const InputDecoration(
              labelText: 'المرحلة *',
              prefixIcon: Icon(Icons.school_outlined),
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
            onChanged: _grades.isEmpty
                ? null
                : (v) {
                    final g = _grades.firstWhere((g) => _gradeUuid(g) == v,
                        orElse: () => {});
                    setState(() {
                      _selectedGradeId = v;
                      _selectedGradeName = _gradeName(g);
                    });
                  },
          ),
          const SizedBox(height: MqSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _accessType,
            isExpanded: true,
            dropdownColor: mq.card,
            decoration: const InputDecoration(
              labelText: 'نوع الوصول',
              prefixIcon: Icon(Icons.lock_open_outlined),
              isDense: true,
            ),
            items: _accessTypes
                .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
                .toList(),
            onChanged: (v) => setState(() {
              _accessType = v ?? 'public_free_by_grade';
              _isFree = _accessType != 'marketplace_paid';
            }),
          ),
          if (_accessType == 'enrolled_students_free') ...[
            const SizedBox(height: MqSpacing.md),
            _liveCoursePicker(context),
          ],
          if (_accessType == 'marketplace_paid') ...[
            const SizedBox(height: MqSpacing.md),
            TextField(
              controller: _price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'السعر (د.ع) *',
                prefixIcon: Icon(Icons.payments_outlined),
                isDense: true,
              ),
            ),
          ],
          const SizedBox(height: MqSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _visibility,
            isExpanded: true,
            dropdownColor: mq.card,
            decoration: const InputDecoration(
              labelText: 'الرؤية',
              prefixIcon: Icon(Icons.visibility_outlined),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'private', child: Text('خاصة')),
              DropdownMenuItem(value: 'public', child: Text('عامة')),
            ],
            onChanged: (v) => setState(() => _visibility = v ?? 'private'),
          ),
          if (widget.isEdit) ...[
            const SizedBox(height: MqSpacing.sm),
            Text(
              '* أي تعديل يعيد الدورة إلى حالة "بانتظار المراجعة" من قبل الإدارة.',
              style: context.text.labelSmall?.copyWith(color: mq.ink3),
            ),
          ],
          if (_coverPhase.isNotEmpty) ...[
            const SizedBox(height: MqSpacing.md),
            Row(children: [
              const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: MqSpacing.sm),
              Text(_coverPhase,
                  style: context.text.labelSmall?.copyWith(color: mq.ink2)),
            ]),
          ],
          if (_error.isNotEmpty) ...[
            const SizedBox(height: MqSpacing.md),
            MqSurface(
              tone: MqSurfaceTone.neutral,
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, size: 18, color: mq.error),
                  const SizedBox(width: MqSpacing.sm),
                  Expanded(
                    child: Text(_error,
                        style:
                            context.text.bodySmall?.copyWith(color: mq.error)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _liveCoursePicker(BuildContext context) {
    final mq = context.mq;
    return Container(
      padding: const EdgeInsets.all(MqSpacing.md),
      decoration: BoxDecoration(
        color: mq.fill,
        borderRadius: MqRadius.brMd,
        border: Border.all(color: mq.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link_rounded, size: 16, color: mq.ink3),
              const SizedBox(width: MqSpacing.xs),
              Expanded(
                child: Text(
                  'الكورسات الحضورية المرتبطة (طلابها يحصلون عليها مجاناً)',
                  style: context.text.labelMedium?.copyWith(color: mq.ink2),
                ),
              ),
            ],
          ),
          const SizedBox(height: MqSpacing.sm),
          if (_liveCourses.isEmpty)
            Text('لا توجد كورسات حضورية. أنشئ كورساً أولاً.',
                style: context.text.bodySmall?.copyWith(color: mq.ink3))
          else
            Wrap(
              spacing: MqSpacing.sm,
              runSpacing: MqSpacing.sm,
              children: [
                for (final c in _liveCourses)
                  () {
                    final id = (c['id'] ?? c['course_id'] ?? '').toString();
                    final name =
                        (c['course_name'] ?? c['name'] ?? '—').toString();
                    if (id.isEmpty) return const SizedBox.shrink();
                    return MqChip(
                      label: name,
                      selected: _targetCourseIds.contains(id),
                      onTap: () => setState(() {
                        if (!_targetCourseIds.remove(id)) {
                          _targetCourseIds.add(id);
                        }
                      }),
                    );
                  }(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _coverField(BuildContext context) {
    final mq = context.mq;
    final hasNew = _coverFile != null;
    final existingUrl = _existingCoverUrl;
    final hasExisting = existingUrl.isNotEmpty;
    final disabled = _submitting;

    Widget preview;
    if (hasNew) {
      preview = Image.file(_coverFile!,
          fit: BoxFit.cover, height: 130, width: double.infinity);
    } else if (hasExisting) {
      preview = Image.network(
        existingUrl,
        fit: BoxFit.cover,
        height: 130,
        width: double.infinity,
        errorBuilder: (ctx, err, stack) =>
            _coverPlaceholder(context, label: 'تعذّر تحميل المعاينة'),
      );
    } else {
      preview = _coverPlaceholder(context);
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: mq.line),
        borderRadius: MqRadius.brMd,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          preview,
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: MqSpacing.sm, vertical: MqSpacing.xs),
            child: Row(
              children: [
                Icon(Icons.image_outlined, size: 16, color: mq.ink3),
                const SizedBox(width: MqSpacing.xs),
                Expanded(
                  child: Text(
                    hasNew
                        ? _coverFileName
                        : (hasExisting ? 'الغلاف الحالي' : 'صورة الغلاف (اختياري)'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelSmall?.copyWith(color: mq.ink2),
                  ),
                ),
                if (hasNew)
                  MqButton.text(
                    label: 'إزالة',
                    size: MqButtonSize.small,
                    onPressed: disabled
                        ? null
                        : () => setState(() {
                              _coverFile = null;
                              _coverFileName = '';
                            }),
                  ),
                MqButton.text(
                  label: hasNew || hasExisting ? 'تغيير' : 'تصفّح',
                  icon: Icons.folder_open_outlined,
                  size: MqButtonSize.small,
                  onPressed: disabled ? null : _pickCover,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverPlaceholder(BuildContext context, {String? label}) {
    final mq = context.mq;
    return Container(
      height: 130,
      width: double.infinity,
      color: mq.fill,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, color: mq.ink3, size: 28),
            const SizedBox(height: MqSpacing.xs),
            Text(
              label ?? 'لا توجد صورة — JPG / PNG / WEBP حتى 5MB',
              style: context.text.labelSmall?.copyWith(color: mq.ink3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _saveBar(BuildContext context) {
    final mq = context.mq;
    final disabled = _submitting || _subjects.isEmpty || _grades.isEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(
          MqSpacing.lg, MqSpacing.sm, MqSpacing.lg, MqSpacing.md),
      decoration: BoxDecoration(
        color: mq.card,
        border: Border(top: BorderSide(color: mq.line)),
      ),
      child: MqButton(
        label: _submitting
            ? 'جارٍ الحفظ…'
            : (widget.isEdit ? 'حفظ التعديلات' : 'إنشاء الدورة'),
        icon: _submitting ? null : Icons.check_rounded,
        loading: _submitting,
        onPressed: disabled ? null : _submit,
      ),
    );
  }
}
