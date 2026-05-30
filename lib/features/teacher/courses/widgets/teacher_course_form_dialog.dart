// Create-course dialog — Flutter mirror of the dashboard's AddCourse.vue.
//
// What it captures (matches POST /api/teacher/courses Zod schema verbatim):
//   - course_name              (required, string)
//   - study_year               (computed from device clock, "YYYY-YYYY")
//   - grade_id                 (UUID from /grades/my-grades)
//   - subject_id               (UUID from /teacher/subjects)
//   - description              (string)
//   - start_date / end_date    (ISO date)
//   - price                    (number ≥ 10000 IQD — dashboard rule)
//   - seats_count              (int ≥ 1)
//   - has_reservation          (bool)
//   - reservation_amount       (number, required when has_reservation)
//   - course_images            (array of data-URL base64 strings, optional)
//
// Image pipeline: image_picker (gallery, multi) → read bytes → base64 →
// data URL → POST as `course_images: [<data-url>, …]`. Same shape the
// dashboard sends via FileReader.readAsDataURL.
//
// Returns the new course id (String) on success — caller uses it to
// refetch / scroll-to-new.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/teacher_api_service.dart';

class TeacherCourseFormDialog extends StatefulWidget {
  const TeacherCourseFormDialog({super.key});

  @override
  State<TeacherCourseFormDialog> createState() => _TeacherCourseFormDialogState();
}

class _TeacherCourseFormDialogState extends State<TeacherCourseFormDialog> {
  final _api = TeacherApiService();
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _seats = TextEditingController(text: '20');
  final _reservation = TextEditingController();

  // Catalog state
  List<Map<String, dynamic>> _grades = [];
  List<Map<String, dynamic>> _subjects = [];
  bool _loadingCatalogs = true;

  // Selections
  String? _gradeId;
  String? _subjectId;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _hasReservation = false;

  // Images
  final List<File> _images = [];
  bool _picking = false;

  // Submit state
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

  /// Compute "YYYY-YYYY" from the device clock — matches the dashboard's
  /// September-rollover heuristic in src/pages/teacher/invoices/manage.vue.
  /// Sep–Dec → currentYear-(currentYear+1); Jan–Aug → (prev)-(current).
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

  /// `/grades/my-grades` returns junction rows shaped as
  ///   `{ id: <teacher_grades.id>, gradeId: <grades.id>, gradeName, ... }`
  /// We need the REAL grades.id (the `gradeId` key) — sending the junction
  /// row's `id` triggers an FK violation server-side.
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
      // Guess a mime type from the extension — server-side image.service
      // accepts the data-URL prefix as a hint but re-detects via magic
      // bytes, so a wrong guess won't break the upload.
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
    if (n < 10000) return 'يجب ألا يقل عن 10,000 د.ع';
    return null;
  }

  String? _validateSeats(String? v) {
    if (v == null || v.trim().isEmpty) return 'مطلوب';
    final n = int.tryParse(v);
    if (n == null || n < 1) return 'عدد المقاعد ≥ 1';
    return null;
  }

  String? _validateReservation(String? v) {
    if (!_hasReservation) return null;
    if (v == null || v.trim().isEmpty) return 'مطلوب';
    final n = num.tryParse(v.replaceAll(',', ''));
    if (n == null || n < 10000) return 'يجب ألا يقل عن 10,000 د.ع';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_gradeId == null) { _safeSetState(() => _error = 'يجب اختيار المرحلة'); return; }
    if (_subjectId == null) { _safeSetState(() => _error = 'يجب اختيار المادة'); return; }
    if (_startDate == null) { _safeSetState(() => _error = 'تاريخ البداية مطلوب'); return; }
    if (_endDate == null) { _safeSetState(() => _error = 'تاريخ النهاية مطلوب'); return; }
    if (_endDate!.isBefore(_startDate!)) {
      _safeSetState(() => _error = 'تاريخ النهاية يجب أن يكون بعد تاريخ البداية');
      return;
    }

    _safeSetState(() { _submitting = true; _error = ''; });
    try {
      final images = await _encodeImagesToDataUrls();
      final isoFmt = DateFormat('yyyy-MM-dd');
      final payload = <String, dynamic>{
        'study_year': _currentStudyYear(),
        'grade_id': _gradeId,
        'subject_id': _subjectId,
        'course_name': _name.text.trim(),
        'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
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
      final id = res['data']?['id']?.toString()
          ?? res['data']?['course']?['id']?.toString();
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
    final scheme = Theme.of(context).colorScheme;

    if (_loadingCatalogs) {
      return AlertDialog(
        title: const Text('إضافة كورس جديد'),
        content: const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final hint = _grades.isEmpty || _subjects.isEmpty
        ? 'لم تضِف بعد ${_grades.isEmpty ? "مراحل" : ""}${_grades.isEmpty && _subjects.isEmpty ? " ولا " : ""}${_subjects.isEmpty ? "مواد" : ""}. أضِفها قبل إنشاء كورس.'
        : '';

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.add_circle_outline, color: scheme.primary),
          const SizedBox(width: 8),
          const Text('إضافة كورس جديد'),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 480,
          child: Form(
            key: _formKey,
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
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'اسم الكورس *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _gradeId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'المرحلة الدراسية *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _grades
                      .map((g) {
                        final id = _gradeUuid(g);
                        final label = _gradeLabel(g);
                        if (id.isEmpty || label.isEmpty) return null;
                        return DropdownMenuItem<String>(value: id, child: Text(label));
                      })
                      .whereType<DropdownMenuItem<String>>()
                      .toList(),
                  onChanged: _grades.isEmpty ? null : (v) => _safeSetState(() => _gradeId = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _subjectId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'المادة *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _subjects
                      .map((s) {
                        final id = _subjectUuid(s);
                        final label = _subjectLabel(s);
                        if (id.isEmpty || label.isEmpty) return null;
                        return DropdownMenuItem<String>(value: id, child: Text(label));
                      })
                      .whereType<DropdownMenuItem<String>>()
                      .toList(),
                  onChanged: _subjects.isEmpty ? null : (v) => _safeSetState(() => _subjectId = v),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _DatePickerField(
                    label: 'تاريخ البداية *',
                    value: _startDate,
                    onTap: () => _pickDate(isStart: true),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: _DatePickerField(
                    label: 'تاريخ النهاية *',
                    value: _endDate,
                    onTap: () => _pickDate(isStart: false),
                  )),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextFormField(
                    controller: _price,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'السعر (د.ع) *',
                      hintText: 'مثال: 250000',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: _validatePrice,
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: TextFormField(
                    controller: _seats,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'عدد المقاعد *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: _validateSeats,
                  )),
                ]),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('يوجد عربون'),
                  value: _hasReservation,
                  onChanged: (v) => _safeSetState(() => _hasReservation = v),
                ),
                if (_hasReservation)
                  TextFormField(
                    controller: _reservation,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'مبلغ العربون (د.ع)',
                      hintText: 'مثال: 100000',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: _validateReservation,
                  ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _description,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'وصف الكورس',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                _buildImagesPicker(scheme),
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
                      Expanded(
                        child: Text(_error,
                            style: TextStyle(color: scheme.onErrorContainer, fontSize: 12)),
                      ),
                    ]),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(null),
          child: const Text('إلغاء'),
        ),
        FilledButton.icon(
          onPressed: (_submitting || _grades.isEmpty || _subjects.isEmpty) ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.save_outlined, size: 16),
          label: const Text('حفظ'),
        ),
      ],
    );
  }

  Widget _buildImagesPicker(ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Icon(Icons.image_outlined, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _images.isEmpty
                    ? 'صور الكورس (اختياري — JPG / PNG / WEBP)'
                    : '${_images.length} صورة مختارة',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
            TextButton.icon(
              onPressed: _submitting ? null : _pickImages,
              icon: const Icon(Icons.add_a_photo_outlined, size: 16),
              label: const Text('إضافة', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ]),
          if (_images.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) => Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_images[i], width: 80, height: 80, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: InkWell(
                      onTap: _submitting ? null : () => _removeImage(i),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(2),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small helper that renders a `TextFormField`-shaped read-only field +
/// opens a date picker on tap.
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
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16),
        ),
        child: Text(
          value == null ? '—' : fmt.format(value!),
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }
}
