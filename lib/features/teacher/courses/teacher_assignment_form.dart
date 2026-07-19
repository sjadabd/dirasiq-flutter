import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/teacher_api_service.dart';
import '../../../core/utils/time_format.dart';
import '../shared/design/teacher_design.dart';

/// Opens the "add new assignment" sheet for [courseId]. Mirrors the dashboard
/// (manage-assignments.vue) form: title/description, subject + session,
/// assigned/due dates, submission type + delivery mode, max score, active
/// toggle, visibility (all / specific students) with student picker, file +
/// image attachments (base64), and link resources.
///
/// Returns `true` if an assignment was created.
Future<bool?> showAssignmentForm({
  required BuildContext context,
  required String courseId,
  required TeacherApiService api,
  Map<String, dynamic>? existing,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => Theme(
      data: isDark ? MqTheme.dark() : MqTheme.light(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: _AssignmentForm(
          courseId: courseId,
          api: api,
          existing: existing,
        ),
      ),
    ),
  );
}

class _AssignmentForm extends StatefulWidget {
  const _AssignmentForm({
    required this.courseId,
    required this.api,
    this.existing,
  });
  final String courseId;
  final TeacherApiService api;
  final Map<String, dynamic>? existing;

  @override
  State<_AssignmentForm> createState() => _AssignmentFormState();
}

class _AssignmentFormState extends State<_AssignmentForm> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _score = TextEditingController(text: '10');

  String? _subjectId;
  String? _sessionId;
  DateTime? _assignedDate;
  DateTime? _dueDate;
  String _submissionType = 'mixed';
  String _deliveryMode = 'mixed';
  bool _isActive = true;
  String _visibility = 'all_students';
  final Set<String> _studentIds = {};
  final List<Map<String, String>> _files = []; // {type, name, base64}
  final List<_ResourceRow> _resources = [];

  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _students = [];
  bool _loadingLists = true;
  bool _saving = false;

  static const _submissionTypes = {
    'text': 'نصّي',
    'link': 'رابط',
    'file': 'ملف',
    'mixed': 'متعدّد',
  };
  static const _deliveryModes = {
    'paper': 'ورقي',
    'electronic': 'إلكتروني',
    'mixed': 'مختلط',
  };

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _prefill(widget.existing!);
    _loadLists();
  }

  void _prefill(Map<String, dynamic> a) {
    _title.text = (a['title'] ?? '').toString();
    _desc.text = (a['description'] ?? '').toString();
    if (a['max_score'] != null) _score.text = a['max_score'].toString();
    _subjectId = a['subject_id']?.toString();
    _sessionId = a['session_id']?.toString();
    _assignedDate = DateTime.tryParse((a['assigned_date'] ?? '').toString());
    _dueDate = DateTime.tryParse((a['due_date'] ?? '').toString());
    final st = (a['submission_type'] ?? '').toString();
    if (_submissionTypes.containsKey(st)) _submissionType = st;
    final att = a['attachments'];
    final dm = (att is Map && att['meta'] is Map)
        ? (att['meta']['delivery_mode'] ?? '').toString()
        : (a['delivery_mode'] ?? '').toString();
    if (_deliveryModes.containsKey(dm)) _deliveryMode = dm;
    _isActive = a['is_active'] == true || a['is_active'] == 1;
    final vis = (a['visibility'] ?? '').toString();
    if (vis == 'all_students' || vis == 'specific_students') _visibility = vis;
    // Existing attachments keep their server URL; new picks add base64.
    if (att is Map && att['files'] is List) {
      for (final f in (att['files'] as List)) {
        if (f is Map) {
          _files.add({
            'type': (f['type'] ?? 'image').toString(),
            'name': (f['name'] ?? 'ملف').toString(),
            if (f['url'] != null) 'url': f['url'].toString(),
            if (f['base64'] != null) 'base64': f['base64'].toString(),
          });
        }
      }
    }
    final res = a['resources'];
    if (res is List) {
      for (final r in res) {
        if (r is Map) {
          final row = _ResourceRow();
          row.title.text = (r['title'] ?? '').toString();
          row.url.text = (r['url'] ?? '').toString();
          _resources.add(row);
        }
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _score.dispose();
    for (final r in _resources) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLists() async {
    try {
      final results = await Future.wait([
        widget.api.fetchMySubjectsCatalog(),
        widget.api.fetchSessions(
          courseId: widget.courseId,
          page: 1,
          limit: 100,
        ),
        widget.api.fetchStudentsByCourse(widget.courseId),
      ]);
      _subjects = (results[0] as List)
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      _sessions = _listOf(results[1] as Map<String, dynamic>);
      _students = _listOf(results[2] as Map<String, dynamic>);
    } catch (_) {
      // Non-fatal: dropdowns just stay empty.
    } finally {
      if (mounted) setState(() => _loadingLists = false);
    }
  }

  List<Map<String, dynamic>> _listOf(Map<String, dynamic> res) {
    final d = res['data'];
    if (d is List) {
      return d
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    if (d is Map && d['items'] is List) {
      return (d['items'] as List)
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return const [];
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate(bool isAssigned) async {
    final now = DateTime.now();
    final base = isAssigned ? (_assignedDate ?? now) : (_dueDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 730)),
      locale: const Locale('ar'),
    );
    if (picked != null) {
      setState(() {
        if (isAssigned) {
          _assignedDate = picked;
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  String _mimeFor(String name) {
    final ext = name.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _pickImages() async {
    try {
      final picked = await ImagePicker().pickMultiImage();
      for (final x in picked) {
        final bytes = await x.readAsBytes();
        final name = x.name;
        _files.add({
          'type': 'image',
          'name': name,
          'base64': 'data:${_mimeFor(name)};base64,${base64Encode(bytes)}',
        });
      }
      if (mounted) setState(() {});
    } catch (_) {
      Get.snackbar(
        'خطأ',
        'تعذّر اختيار الصور',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _pickFiles() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: true,
      );
      if (res == null) return;
      for (final f in res.files) {
        final bytes = f.bytes;
        if (bytes == null) continue;
        _files.add({
          'type': 'pdf',
          'name': f.name,
          'base64': 'data:${_mimeFor(f.name)};base64,${base64Encode(bytes)}',
        });
      }
      if (mounted) setState(() {});
    } catch (_) {
      Get.snackbar(
        'خطأ',
        'تعذّر اختيار الملفات',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      Get.snackbar(
        'تنبيه',
        'العنوان مطلوب',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (_visibility == 'specific_students' && _studentIds.isEmpty) {
      Get.snackbar(
        'تنبيه',
        'اختر طالباً واحداً على الأقل',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final resources = _resources
        .where((r) => r.url.text.trim().isNotEmpty)
        .map(
          (r) => {
            'type': 'link',
            'title': r.title.text.trim(),
            'url': r.url.text.trim(),
          },
        )
        .toList();

    final payload = <String, dynamic>{
      'course_id': widget.courseId,
      'title': title,
      if (_desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
      if (_subjectId != null) 'subject_id': _subjectId,
      if (_sessionId != null) 'session_id': _sessionId,
      if (_assignedDate != null) 'assigned_date': _fmtDate(_assignedDate!),
      if (_dueDate != null) 'due_date': _fmtDate(_dueDate!),
      'submission_type': _submissionType,
      'delivery_mode': _deliveryMode,
      'max_score': int.tryParse(_score.text.trim()) ?? 10,
      'is_active': _isActive,
      'visibility': _visibility,
      if (_visibility == 'specific_students')
        'recipients': {'studentIds': _studentIds.toList()},
      'attachments': {
        'files': _files,
        'meta': {'delivery_mode': _deliveryMode},
      },
      'resources': resources,
    };

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await widget.api.updateAssignment(
          widget.existing!['id'].toString(),
          payload,
        );
      } else {
        await widget.api.createAssignment(payload);
      }
      if (mounted) Navigator.pop(context, true);
      Get.snackbar(
        'تم',
        _isEdit ? 'تم حفظ التعديلات' : 'تم إنشاء الواجب',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      Get.snackbar(
        'خطأ',
        _isEdit ? 'تعذّر حفظ التعديلات' : 'تعذّر إنشاء الواجب',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: BoxDecoration(
          color: mq.card,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(MqRadius.xl),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              MqSpacing.lg,
              MqSpacing.sm,
              MqSpacing.lg,
              MqSpacing.lg,
            ),
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
                      color: mq.line,
                      borderRadius: MqRadius.brPill,
                    ),
                  ),
                ),
                _header(context),
                const SizedBox(height: MqSpacing.lg),
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'العنوان *',
                    hintText: 'مثال: واجب الوحدة الأولى',
                    prefixIcon: Icon(Icons.title_rounded),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: MqSpacing.md),
                TextField(
                  controller: _desc,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'الوصف',
                    alignLabelWithHint: true,
                    isDense: true,
                  ),
                ),
                const SizedBox(height: MqSpacing.md),
                if (_loadingLists)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: MqSpacing.sm),
                    child: LinearProgressIndicator(),
                  ),
                _dropdown(
                  label: 'المادة (اختياري)',
                  icon: Icons.book_outlined,
                  value: _subjectId,
                  items: {
                    for (final s in _subjects)
                      s['id']?.toString() ?? '':
                          (s['name'] ?? s['title'] ?? '—').toString(),
                  },
                  onChanged: (v) => setState(() => _subjectId = v),
                ),
                const SizedBox(height: MqSpacing.md),
                _dropdown(
                  label: 'الجلسة (اختياري)',
                  icon: Icons.event_outlined,
                  value: _sessionId,
                  items: {
                    for (final s in _sessions)
                      s['id']?.toString() ?? '': _sessionLabel(s),
                  },
                  onChanged: (v) => setState(() => _sessionId = v),
                ),
                const SizedBox(height: MqSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _dateField('تاريخ الإسناد', _assignedDate, true),
                    ),
                    const SizedBox(width: MqSpacing.sm),
                    Expanded(
                      child: _dateField('تاريخ التسليم', _dueDate, false),
                    ),
                  ],
                ),
                const SizedBox(height: MqSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _dropdown(
                        label: 'نوع التسليم',
                        icon: Icons.assignment_turned_in_outlined,
                        value: _submissionType,
                        items: _submissionTypes,
                        onChanged: (v) =>
                            setState(() => _submissionType = v ?? 'mixed'),
                      ),
                    ),
                    const SizedBox(width: MqSpacing.sm),
                    Expanded(
                      child: _dropdown(
                        label: 'نمط التسليم',
                        icon: Icons.local_shipping_outlined,
                        value: _deliveryMode,
                        items: _deliveryModes,
                        onChanged: (v) =>
                            setState(() => _deliveryMode = v ?? 'mixed'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MqSpacing.md),
                TextField(
                  controller: _score,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: false,
                    signed: false,
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'الدرجة القصوى',
                    prefixIcon: Icon(Icons.grade_outlined),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: MqSpacing.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('مفعّل', style: context.text.bodyMedium),
                  value: _isActive,
                  activeThumbColor: mq.accent,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
                const SizedBox(height: MqSpacing.xs),
                _visibilitySection(context),
                const SizedBox(height: MqSpacing.lg),
                _attachmentsSection(context),
                const SizedBox(height: MqSpacing.lg),
                _resourcesSection(context),
                const SizedBox(height: MqSpacing.xl),
                MqButton(
                  label: _saving
                      ? 'جارٍ الحفظ…'
                      : (_isEdit ? 'حفظ التعديلات' : 'إضافة الواجب'),
                  icon: _saving ? null : Icons.check_rounded,
                  loading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final mq = context.mq;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: mq.accentSoft,
            borderRadius: MqRadius.brSm,
          ),
          child: Icon(
            Icons.assignment_add,
            size: MqSize.iconSm,
            color: mq.accent,
          ),
        ),
        const SizedBox(width: MqSpacing.sm),
        Expanded(
          child: Text(
            _isEdit ? 'تعديل الواجب' : 'إضافة واجب جديد',
            style: context.text.titleMedium,
          ),
        ),
        InkWell(
          onTap: () => Navigator.pop(context),
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.close_rounded, color: mq.ink3),
          ),
        ),
      ],
    );
  }

  static const _weekdays = [
    'الأحد',
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
  ];

  String _sessionLabel(Map<String, dynamic> s) {
    final wd = (s['weekday'] is num) ? (s['weekday'] as num).toInt() : -1;
    final day = (wd >= 0 && wd < 7) ? _weekdays[wd] : '';
    final start = formatTime12(s['start_time']);
    final grade = (s['grade_name'] ?? '').toString();
    final parts = [day, start, grade].where((x) => x.isNotEmpty).toList();
    return parts.isEmpty ? 'حصة' : parts.join(' · ');
  }

  Widget _dropdown({
    required String label,
    required IconData icon,
    required String? value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final mq = context.mq;
    final safeValue = items.containsKey(value) ? value : null;
    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      isExpanded: true,
      dropdownColor: mq.card,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        isDense: true,
      ),
      items: [
        for (final e in items.entries)
          DropdownMenuItem(
            value: e.key,
            child: Text(e.value, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }

  Widget _dateField(String label, DateTime? value, bool isAssigned) {
    final mq = context.mq;
    return InkWell(
      onTap: () => _pickDate(isAssigned),
      borderRadius: MqRadius.brMd,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          prefixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(
          value == null ? 'اختر' : _fmtDate(value),
          style: context.text.bodyMedium?.copyWith(
            color: value == null ? mq.ink3 : mq.ink,
          ),
        ),
      ),
    );
  }

  Widget _visibilitySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('الظهور', style: context.text.labelMedium),
        const SizedBox(height: MqSpacing.sm),
        Wrap(
          spacing: MqSpacing.sm,
          children: [
            MqChip(
              label: 'كل الطلاب',
              selected: _visibility == 'all_students',
              onTap: () => setState(() => _visibility = 'all_students'),
            ),
            MqChip(
              label: 'طلاب محدّدون',
              selected: _visibility == 'specific_students',
              onTap: () => setState(() => _visibility = 'specific_students'),
            ),
          ],
        ),
        if (_visibility == 'specific_students') ...[
          const SizedBox(height: MqSpacing.sm),
          if (_students.isEmpty)
            Text(
              'لا يوجد طلاب في هذه الدورة',
              style: context.text.bodySmall?.copyWith(color: context.mq.ink3),
            )
          else
            Wrap(
              spacing: MqSpacing.sm,
              runSpacing: MqSpacing.sm,
              children: [
                for (final s in _students)
                  () {
                    final id = (s['student_id'] ?? s['id'] ?? '').toString();
                    final name = (s['student_name'] ?? s['name'] ?? '—')
                        .toString();
                    return MqChip(
                      label: name,
                      selected: _studentIds.contains(id),
                      onTap: () => setState(() {
                        if (_studentIds.contains(id)) {
                          _studentIds.remove(id);
                        } else if (id.isNotEmpty) {
                          _studentIds.add(id);
                        }
                      }),
                    );
                  }(),
              ],
            ),
        ],
      ],
    );
  }

  Widget _attachmentsSection(BuildContext context) {
    final mq = context.mq;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('المرفقات', style: context.text.labelMedium),
        const SizedBox(height: MqSpacing.sm),
        Row(
          children: [
            Expanded(
              child: MqButton.secondary(
                label: 'صور',
                icon: Icons.image_outlined,
                size: MqButtonSize.small,
                onPressed: _pickImages,
              ),
            ),
            const SizedBox(width: MqSpacing.sm),
            Expanded(
              child: MqButton.secondary(
                label: 'ملفات PDF',
                icon: Icons.picture_as_pdf_outlined,
                size: MqButtonSize.small,
                onPressed: _pickFiles,
              ),
            ),
          ],
        ),
        for (var i = 0; i < _files.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: MqSpacing.sm),
            child: Row(
              children: [
                Icon(
                  _files[i]['type'] == 'pdf'
                      ? Icons.picture_as_pdf_outlined
                      : Icons.image_outlined,
                  size: MqSize.iconSm,
                  color: mq.accent,
                ),
                const SizedBox(width: MqSpacing.sm),
                Expanded(
                  child: Text(
                    _files[i]['name'] ?? 'ملف',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall,
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _files.removeAt(i)),
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: MqSize.iconSm,
                      color: mq.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _resourcesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('روابط الموارد', style: context.text.labelMedium),
            const Spacer(),
            MqButton.text(
              label: 'إضافة رابط',
              icon: Icons.add_link_rounded,
              size: MqButtonSize.small,
              onPressed: () => setState(() => _resources.add(_ResourceRow())),
            ),
          ],
        ),
        for (var i = 0; i < _resources.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: MqSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _resources[i].title,
                    decoration: const InputDecoration(
                      labelText: 'العنوان',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: MqSpacing.sm),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _resources[i].url,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'الرابط',
                      isDense: true,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() {
                    _resources[i].dispose();
                    _resources.removeAt(i);
                  }),
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: MqSize.iconSm,
                      color: context.mq.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ResourceRow {
  final TextEditingController title = TextEditingController();
  final TextEditingController url = TextEditingController();
  void dispose() {
    title.dispose();
    url.dispose();
  }
}
