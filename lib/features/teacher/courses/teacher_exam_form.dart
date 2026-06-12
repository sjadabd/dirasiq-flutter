import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:get/get.dart';

import '../../../core/services/teacher_api_service.dart';
import '../shared/design/teacher_design.dart';

/// Opens the "add new exam" sheet for [courseId]. Mirrors the dashboard
/// (manage-exams.vue): subject, optional linked sessions, exam date+time,
/// type (daily/monthly), max score, description, notes.
///
/// Returns `true` if an exam was created.
Future<bool?> showExamForm({
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
        child: _ExamForm(courseId: courseId, api: api, existing: existing),
      ),
    ),
  );
}

class _ExamForm extends StatefulWidget {
  const _ExamForm({required this.courseId, required this.api, this.existing});
  final String courseId;
  final TeacherApiService api;
  final Map<String, dynamic>? existing;

  @override
  State<_ExamForm> createState() => _ExamFormState();
}

class _ExamFormState extends State<_ExamForm> {
  final _desc = TextEditingController();
  final _notes = TextEditingController();
  final _score = TextEditingController(text: '20');

  String? _subjectId;
  final Set<String> _sessionIds = {};
  DateTime? _date;
  TimeOfDay? _time;
  String _examType = 'daily';

  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _sessions = [];
  bool _loadingLists = true;
  bool _saving = false;

  static const _examTypes = {'daily': 'يومي', 'monthly': 'شهري'};
  static const _weekdays = [
    'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'
  ];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _prefill(widget.existing!);
    _loadLists();
  }

  void _prefill(Map<String, dynamic> e) {
    _subjectId = e['subject_id']?.toString();
    if (e['max_score'] != null) _score.text = e['max_score'].toString();
    _desc.text = (e['description'] ?? '').toString();
    _notes.text = (e['notes'] ?? '').toString();
    final t = (e['exam_type'] ?? '').toString();
    if (_examTypes.containsKey(t)) _examType = t;
    final dt = DateTime.tryParse((e['exam_date'] ?? '').toString());
    if (dt != null) {
      final l = dt.toLocal();
      _date = DateTime(l.year, l.month, l.day);
      _time = TimeOfDay(hour: l.hour, minute: l.minute);
    }
    final sessions = e['sessions'];
    if (sessions is List) {
      for (final s in sessions) {
        if (s is Map && s['id'] != null) _sessionIds.add(s['id'].toString());
      }
    }
  }

  @override
  void dispose() {
    _desc.dispose();
    _notes.dispose();
    _score.dispose();
    super.dispose();
  }

  Future<void> _loadLists() async {
    try {
      final results = await Future.wait([
        widget.api.fetchMySubjectsCatalog(),
        widget.api.fetchSessions(courseId: widget.courseId, page: 1, limit: 100),
      ]);
      _subjects = (results[0] as List)
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      _sessions = _listOf(results[1] as Map<String, dynamic>);
    } catch (_) {
      // Non-fatal — dropdowns just stay empty.
    } finally {
      if (mounted) setState(() => _loadingLists = false);
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

  String get _dateLabel {
    if (_date == null) return 'اختر التاريخ';
    final d = _date!;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String get _timeLabel {
    final t = _time;
    if (t == null) return 'اختر الوقت';
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.period == DayPeriod.am ? 'ص' : 'م'}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 730)),
      locale: const Locale('ar'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  String _sessionLabel(Map<String, dynamic> s) {
    final wd = (s['weekday'] is num) ? (s['weekday'] as num).toInt() : -1;
    final day = (wd >= 0 && wd < 7) ? _weekdays[wd] : '';
    final start = (s['start_time'] ?? '').toString();
    final parts = [day, start].where((x) => x.isNotEmpty).toList();
    return parts.isEmpty ? 'حصة' : parts.join(' · ');
  }

  Future<void> _save() async {
    if (_subjectId == null) {
      Get.snackbar('تنبيه', 'اختر المادة', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (_date == null || _time == null) {
      Get.snackbar('تنبيه', 'حدّد تاريخ ووقت الاختبار',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final score = int.tryParse(_score.text.trim());
    if (score == null || score <= 0) {
      Get.snackbar('تنبيه', 'أدخل درجة قصوى صحيحة',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final examAt = DateTime(_date!.year, _date!.month, _date!.day, _time!.hour,
        _time!.minute);
    final payload = <String, dynamic>{
      'course_id': widget.courseId,
      'subject_id': _subjectId,
      if (_sessionIds.isNotEmpty) 'sessionIds': _sessionIds.toList(),
      'exam_date': examAt.toUtc().toIso8601String(),
      'exam_type': _examType,
      'max_score': score,
      if (_desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
      if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
    };

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await widget.api
            .updateExam(widget.existing!['id'].toString(), payload);
      } else {
        await widget.api.createExam(payload);
      }
      if (mounted) Navigator.pop(context, true);
      Get.snackbar('تم', _isEdit ? 'تم حفظ التعديلات' : 'تم إنشاء الاختبار',
          snackPosition: SnackPosition.BOTTOM);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      Get.snackbar('خطأ', _isEdit ? 'تعذّر حفظ التعديلات' : 'تعذّر إنشاء الاختبار',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        decoration: BoxDecoration(
          color: mq.card,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(MqRadius.xl)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                MqSpacing.lg, MqSpacing.sm, MqSpacing.lg, MqSpacing.lg),
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
                _header(context),
                const SizedBox(height: MqSpacing.lg),
                if (_loadingLists)
                  const Padding(
                    padding: EdgeInsets.only(bottom: MqSpacing.sm),
                    child: LinearProgressIndicator(),
                  ),
                _dropdown(
                  label: 'المادة *',
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
                Text('نوع الاختبار', style: context.text.labelMedium),
                const SizedBox(height: MqSpacing.sm),
                Wrap(
                  spacing: MqSpacing.sm,
                  children: [
                    for (final e in _examTypes.entries)
                      MqChip(
                        label: e.value,
                        selected: _examType == e.key,
                        onTap: () => setState(() => _examType = e.key),
                      ),
                  ],
                ),
                const SizedBox(height: MqSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _pickField('تاريخ الاختبار *', _dateLabel,
                          Icons.calendar_today_outlined, _pickDate),
                    ),
                    const SizedBox(width: MqSpacing.sm),
                    Expanded(
                      child: _pickField('وقت الاختبار *', _timeLabel,
                          Icons.schedule_outlined, _pickTime),
                    ),
                  ],
                ),
                const SizedBox(height: MqSpacing.md),
                TextField(
                  controller: _score,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: false, signed: false),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'الدرجة القصوى *',
                    prefixIcon: Icon(Icons.grade_outlined),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: MqSpacing.md),
                if (_sessions.isNotEmpty) ...[
                  Text('ربط بجلسات (اختياري)', style: context.text.labelMedium),
                  const SizedBox(height: MqSpacing.sm),
                  Wrap(
                    spacing: MqSpacing.sm,
                    runSpacing: MqSpacing.sm,
                    children: [
                      for (final s in _sessions)
                        () {
                          final id = (s['id'] ?? '').toString();
                          return MqChip(
                            label: _sessionLabel(s),
                            selected: _sessionIds.contains(id),
                            onTap: () => setState(() {
                              if (_sessionIds.contains(id)) {
                                _sessionIds.remove(id);
                              } else if (id.isNotEmpty) {
                                _sessionIds.add(id);
                              }
                            }),
                          );
                        }(),
                    ],
                  ),
                  const SizedBox(height: MqSpacing.md),
                ],
                TextField(
                  controller: _desc,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'الوصف (اختياري)',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: MqSpacing.md),
                TextField(
                  controller: _notes,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: MqSpacing.xl),
                MqButton(
                  label: _saving
                      ? 'جارٍ الحفظ…'
                      : (_isEdit ? 'حفظ التعديلات' : 'إضافة الاختبار'),
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
          decoration:
              BoxDecoration(color: mq.accentSoft, borderRadius: MqRadius.brSm),
          child: Icon(Icons.quiz_outlined,
              size: MqSize.iconSm, color: mq.accent),
        ),
        const SizedBox(width: MqSpacing.sm),
        Expanded(
          child: Text(_isEdit ? 'تعديل الاختبار' : 'إضافة اختبار جديد',
              style: context.text.titleMedium),
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

  Widget _pickField(
      String label, String value, IconData icon, VoidCallback onTap) {
    final mq = context.mq;
    final isPlaceholder = value.startsWith('اختر');
    return InkWell(
      onTap: onTap,
      borderRadius: MqRadius.brMd,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          prefixIcon: Icon(icon),
        ),
        child: Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodyMedium
                ?.copyWith(color: isPlaceholder ? mq.ink3 : mq.ink)),
      ),
    );
  }
}
