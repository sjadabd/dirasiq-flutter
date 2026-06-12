// Create-course sheet — Flutter mirror of the dashboard's AddCourse.vue.
//
// Restyled to the Teacher Design System as an animated bottom sheet. All data
// logic is UNCHANGED — it captures the exact POST /api/teacher/courses Zod
// payload (course_name, study_year, grade_id, subject_id, description,
// start/end dates, price ≥ 10000, seats ≥ 1, has_reservation,
// reservation_amount, course_images as base64 data-URLs) and returns the new
// course id (String) via Navigator.pop on success.
//
// Open it with `showModalBottomSheet<String?>(... builder: (_) =>
// const TeacherCourseFormDialog())`.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/services/teacher_api_service.dart';
import '../../shared/design/teacher_design.dart';

class TeacherCourseFormDialog extends StatefulWidget {
  const TeacherCourseFormDialog({super.key});

  @override
  State<TeacherCourseFormDialog> createState() =>
      _TeacherCourseFormDialogState();
}

class _TeacherCourseFormDialogState extends State<TeacherCourseFormDialog> {
  final _api = TeacherApiService();
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _seats = TextEditingController(text: '20');
  final _reservation = TextEditingController();

  List<Map<String, dynamic>> _grades = [];
  List<Map<String, dynamic>> _subjects = [];
  bool _loadingCatalogs = true;

  String? _gradeId;
  String? _subjectId;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _hasReservation = false;

  final List<File> _images = [];
  bool _picking = false;

  bool _submitting = false;
  String _error = '';

  bool _disposed = false;

  void _safeSetState(VoidCallback fn) {
    if (!mounted || _disposed) return;
    setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _loadCatalogs();
  }

  @override
  void dispose() {
    _disposed = true;
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _seats.dispose();
    _reservation.dispose();
    super.dispose();
  }

  String _currentStudyYear() {
    final now = DateTime.now();
    final start = now.month >= 9 ? now.year : now.year - 1;
    return '$start-${start + 1}';
  }

  Future<void> _loadCatalogs() async {
    try {
      final results = await Future.wait([
        _api.fetchMyGradesCatalog(),
        _api.fetchMySubjectsCatalog(),
      ]);
      _safeSetState(() {
        _grades = results[0];
        _subjects = results[1];
        _loadingCatalogs = false;
      });
    } catch (e) {
      _safeSetState(() {
        _loadingCatalogs = false;
        _error = 'تعذّر تحميل المراحل / المواد';
      });
    }
  }

  String _gradeUuid(Map g) => (g['gradeId'] ?? g['id'])?.toString() ?? '';
  String _gradeLabel(Map g) =>
      (g['gradeName'] ?? g['name'] ?? g['title'])?.toString() ?? '';

  String _subjectUuid(Map s) => (s['id'])?.toString() ?? '';
  String _subjectLabel(Map s) =>
      (s['name'] ?? s['title'] ?? s['subject'])?.toString() ?? '';

  Future<void> _pickImages() async {
    if (_picking) return;
    _picking = true;
    try {
      final picker = ImagePicker();
      final files = await picker.pickMultiImage(imageQuality: 75);
      if (files.isEmpty) return;
      final newFiles = files.map((x) => File(x.path)).toList();
      _safeSetState(() {
        _images.addAll(newFiles);
      });
    } catch (e) {
      _safeSetState(() => _error = 'تعذّر اختيار الصور: $e');
    } finally {
      _picking = false;
    }
  }

  void _removeImage(int index) {
    _safeSetState(() => _images.removeAt(index));
  }

  Future<List<String>> _encodeImagesToDataUrls() async {
    final out = <String>[];
    for (final f in _images) {
      final bytes = await f.readAsBytes();
      final ext = f.path.split('.').last.toLowerCase();
      final mime = (ext == 'png')
          ? 'image/png'
          : (ext == 'webp')
              ? 'image/webp'
              : 'image/jpeg';
      out.add('data:$mime;base64,${base64Encode(bytes)}');
    }
    return out;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = (isStart ? _startDate : _endDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('ar'),
    );
    if (picked == null) return;
    _safeSetState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  String? _validatePrice(String? v) {
    if (v == null || v.trim().isEmpty) return 'مطلوب';
    final n = num.tryParse(v.replaceAll(',', ''));
    if (n == null) return 'قيمة غير صحيحة';
    if (n < 10000) return 'يجب ألا يقل عن 10,000';
    return null;
  }

  String? _validateSeats(String? v) {
    if (v == null || v.trim().isEmpty) return 'مطلوب';
    final n = int.tryParse(v);
    if (n == null || n < 1) return '≥ 1';
    return null;
  }

  String? _validateReservation(String? v) {
    if (!_hasReservation) return null;
    if (v == null || v.trim().isEmpty) return 'مطلوب';
    final n = num.tryParse(v.replaceAll(',', ''));
    if (n == null || n < 10000) return 'يجب ألا يقل عن 10,000';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_gradeId == null) {
      _safeSetState(() => _error = 'يجب اختيار المرحلة');
      return;
    }
    if (_subjectId == null) {
      _safeSetState(() => _error = 'يجب اختيار المادة');
      return;
    }
    if (_startDate == null) {
      _safeSetState(() => _error = 'تاريخ البداية مطلوب');
      return;
    }
    if (_endDate == null) {
      _safeSetState(() => _error = 'تاريخ النهاية مطلوب');
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      _safeSetState(
          () => _error = 'تاريخ النهاية يجب أن يكون بعد تاريخ البداية');
      return;
    }

    _safeSetState(() {
      _submitting = true;
      _error = '';
    });
    try {
      final images = await _encodeImagesToDataUrls();
      final isoFmt = DateFormat('yyyy-MM-dd');
      final payload = <String, dynamic>{
        'study_year': _currentStudyYear(),
        'grade_id': _gradeId,
        'subject_id': _subjectId,
        'course_name': _name.text.trim(),
        'description':
            _description.text.trim().isEmpty ? null : _description.text.trim(),
        'start_date': isoFmt.format(_startDate!),
        'end_date': isoFmt.format(_endDate!),
        'price': num.parse(_price.text.replaceAll(',', '')),
        'seats_count': int.parse(_seats.text),
        'has_reservation': _hasReservation,
        'reservation_amount': _hasReservation
            ? num.parse(_reservation.text.replaceAll(',', ''))
            : null,
        if (images.isNotEmpty) 'course_images': images,
      };
      final res = await _api.createCourse(payload);
      final id = res['data']?['id']?.toString() ??
          res['data']?['course']?['id']?.toString();
      if (!mounted) return;
      Navigator.of(context).pop(id);
    } catch (e) {
      _safeSetState(() {
        _error = 'تعذّر إنشاء الكورس. تحقّق من الحقول وحاول مجدّداً.';
      });
    } finally {
      _safeSetState(() => _submitting = false);
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
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.92,
              ),
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
                                child: Center(child: CircularProgressIndicator()),
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
          margin: const EdgeInsets.only(top: MqSpacing.sm, bottom: MqSpacing.sm),
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
            child:
                Icon(Icons.add_rounded, size: MqSize.iconSm, color: mq.accent),
          ),
          const SizedBox(width: MqSpacing.sm),
          Expanded(
            child: Text('إضافة كورس جديد', style: context.text.titleMedium),
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
    final missingCatalog = _grades.isEmpty || _subjects.isEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          MqSpacing.lg, MqSpacing.sm, MqSpacing.lg, MqSpacing.lg),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (missingCatalog)
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
                        child: Text(
                          'أضِف ${_grades.isEmpty ? 'مراحل' : ''}'
                          '${_grades.isEmpty && _subjects.isEmpty ? ' و' : ''}'
                          '${_subjects.isEmpty ? 'مواد' : ''} أولاً قبل إنشاء كورس.',
                          style: context.text.bodySmall
                              ?.copyWith(color: mq.ink2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'اسم الكورس *',
                prefixIcon: Icon(Icons.book_outlined),
                isDense: true,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: MqSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _gradeId,
              isExpanded: true,
              dropdownColor: mq.card,
              decoration: const InputDecoration(
                labelText: 'المرحلة الدراسية *',
                prefixIcon: Icon(Icons.school_outlined),
                isDense: true,
              ),
              items: _grades
                  .map((g) {
                    final id = _gradeUuid(g);
                    final label = _gradeLabel(g);
                    if (id.isEmpty || label.isEmpty) return null;
                    return DropdownMenuItem<String>(
                        value: id, child: Text(label));
                  })
                  .whereType<DropdownMenuItem<String>>()
                  .toList(),
              onChanged: _grades.isEmpty
                  ? null
                  : (v) => _safeSetState(() => _gradeId = v),
            ),
            const SizedBox(height: MqSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _subjectId,
              isExpanded: true,
              dropdownColor: mq.card,
              decoration: const InputDecoration(
                labelText: 'المادة *',
                prefixIcon: Icon(Icons.menu_book_outlined),
                isDense: true,
              ),
              items: _subjects
                  .map((s) {
                    final id = _subjectUuid(s);
                    final label = _subjectLabel(s);
                    if (id.isEmpty || label.isEmpty) return null;
                    return DropdownMenuItem<String>(
                        value: id, child: Text(label));
                  })
                  .whereType<DropdownMenuItem<String>>()
                  .toList(),
              onChanged: _subjects.isEmpty
                  ? null
                  : (v) => _safeSetState(() => _subjectId = v),
            ),
            const SizedBox(height: MqSpacing.md),
            Row(children: [
              Expanded(
                child: _DatePickerField(
                  label: 'تاريخ البداية *',
                  value: _startDate,
                  onTap: () => _pickDate(isStart: true),
                ),
              ),
              const SizedBox(width: MqSpacing.sm),
              Expanded(
                child: _DatePickerField(
                  label: 'تاريخ النهاية *',
                  value: _endDate,
                  onTap: () => _pickDate(isStart: false),
                ),
              ),
            ]),
            const SizedBox(height: MqSpacing.md),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'السعر (د.ع) *',
                    isDense: true,
                  ),
                  validator: _validatePrice,
                ),
              ),
              const SizedBox(width: MqSpacing.sm),
              Expanded(
                child: TextFormField(
                  controller: _seats,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'المقاعد *',
                    isDense: true,
                  ),
                  validator: _validateSeats,
                ),
              ),
            ]),
            const SizedBox(height: MqSpacing.sm),
            MqSurface(
              tone: MqSurfaceTone.neutral,
              padding: const EdgeInsets.symmetric(horizontal: MqSpacing.sm),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeTrackColor: mq.accent,
                title: Text('يوجد عربون', style: context.text.bodyMedium),
                value: _hasReservation,
                onChanged: (v) => _safeSetState(() => _hasReservation = v),
              ),
            ),
            if (_hasReservation) ...[
              const SizedBox(height: MqSpacing.md),
              TextFormField(
                controller: _reservation,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'مبلغ العربون (د.ع)',
                  prefixIcon: Icon(Icons.savings_outlined),
                  isDense: true,
                ),
                validator: _validateReservation,
              ),
            ],
            const SizedBox(height: MqSpacing.md),
            TextFormField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'وصف الكورس',
                hintText: 'وصف اختياري...',
              ),
            ),
            const SizedBox(height: MqSpacing.md),
            _imagesPicker(context),
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
                          style: context.text.bodySmall
                              ?.copyWith(color: mq.error)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _imagesPicker(BuildContext context) {
    final mq = context.mq;
    return Container(
      padding: const EdgeInsets.all(MqSpacing.md),
      decoration: BoxDecoration(
        color: mq.fill,
        borderRadius: MqRadius.brMd,
        border: Border.all(color: mq.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.image_outlined, size: 18, color: mq.ink3),
              const SizedBox(width: MqSpacing.sm),
              Expanded(
                child: Text(
                  _images.isEmpty
                      ? 'صور الكورس (اختياري)'
                      : '${_images.length} صورة مختارة',
                  style: context.text.labelMedium?.copyWith(color: mq.ink2),
                ),
              ),
              MqButton.text(
                label: 'إضافة',
                icon: Icons.add_a_photo_outlined,
                size: MqButtonSize.small,
                onPressed: _submitting ? null : _pickImages,
              ),
            ],
          ),
          if (_images.isNotEmpty) ...[
            const SizedBox(height: MqSpacing.sm),
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                separatorBuilder: (_, _) => const SizedBox(width: MqSpacing.sm),
                itemBuilder: (ctx, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: MqRadius.brSm,
                      child: Image.file(_images[i],
                          width: 76, height: 76, fit: BoxFit.cover),
                    ),
                    PositionedDirectional(
                      top: 2,
                      end: 2,
                      child: InkWell(
                        onTap: _submitting ? null : () => _removeImage(i),
                        child: Container(
                          decoration: BoxDecoration(
                              color: mq.error, shape: BoxShape.circle),
                          padding: const EdgeInsets.all(2),
                          child: const Icon(Icons.close,
                              size: 13, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _saveBar(BuildContext context) {
    final mq = context.mq;
    final disabled = _submitting || _grades.isEmpty || _subjects.isEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(
          MqSpacing.lg, MqSpacing.sm, MqSpacing.lg, MqSpacing.md),
      decoration: BoxDecoration(
        color: mq.card,
        border: Border(top: BorderSide(color: mq.line)),
      ),
      child: MqButton(
        label: _submitting ? 'جارٍ الحفظ…' : 'حفظ الكورس',
        icon: _submitting ? null : Icons.check_rounded,
        loading: _submitting,
        onPressed: disabled ? null : _submit,
      ),
    );
  }
}

/// Read-only date field that opens a date picker on tap (design-system styled
/// via the active [InputDecorationTheme]).
class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy-MM-dd');
    return InkWell(
      onTap: onTap,
      borderRadius: MqRadius.brMd,
      child: InputDecorator(
        decoration: const InputDecoration(
          isDense: true,
          suffixIcon: Icon(Icons.calendar_today_outlined, size: 16),
        ),
        child: Text(
          value == null ? label : fmt.format(value!),
          style: context.text.bodyMedium?.copyWith(
              color: value == null ? context.mq.ink3 : context.mq.ink),
        ),
      ),
    );
  }
}
