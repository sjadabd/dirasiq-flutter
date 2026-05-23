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

import 'package:flutter/material.dart';

import '../../../../core/services/teacher_api_service.dart';

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
            !_grades.any((g) => g['id']?.toString() == _selectedGradeId)) {
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

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.isEmpty) { setState(() => _error = 'العنوان مطلوب'); return; }
    if ((_selectedSubject ?? '').isEmpty) { setState(() => _error = 'يجب اختيار المادة'); return; }
    if ((_selectedGradeId ?? '').isEmpty || _selectedGradeName.isEmpty) {
      setState(() => _error = 'يجب اختيار المرحلة'); return;
    }
    setState(() { _submitting = true; _error = ''; });
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
      if (widget.isEdit) {
        final id = widget.initial!['id'].toString();
        await _api.updateVideoCourse(id, payload);
        if (!mounted) return;
        Navigator.of(context).pop(id);
      } else {
        final res = await _api.createVideoCourse(payload);
        final id = res['data']?['course']?['id']?.toString();
        if (!mounted) return;
        Navigator.of(context).pop(id);
      }
    } catch (e) {
      if (mounted) setState(() => _error = widget.isEdit ? 'تعذّر حفظ التعديلات' : 'تعذّر إنشاء الدورة');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
              initialValue: _selectedGradeId != null && _grades.any((g) => g['id']?.toString() == _selectedGradeId)
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
                    final id = g['id']?.toString();
                    final name = _gradeName(g);
                    if (id == null || id.isEmpty || name.isEmpty) return null;
                    return DropdownMenuItem<String>(value: id, child: Text(name));
                  })
                  .whereType<DropdownMenuItem<String>>()
                  .toList(),
              onChanged: _grades.isEmpty ? null : (v) {
                final g = _grades.firstWhere((g) => g['id']?.toString() == v, orElse: () => {});
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
