import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/teacher_api_service.dart';
import '../shared/design/teacher_design.dart';

/// The six evaluation axes (key → Arabic label), matching the dashboard
/// (bulk-upsert-evaluations.vue) and the backend student_evaluations columns.
const List<({String key, String label})> kEvalAxes = [
  (key: 'scientific_level', label: 'علمي'),
  (key: 'behavioral_level', label: 'سلوكي'),
  (key: 'attendance_level', label: 'حضور'),
  (key: 'homework_preparation', label: 'واجب'),
  (key: 'participation_level', label: 'مشاركة'),
  (key: 'instruction_following', label: 'تعليمات'),
];

/// The five rating levels (value → short Arabic label).
const List<({String value, String label})> kEvalLevels = [
  (value: 'excellent', label: 'ممتاز'),
  (value: 'very_good', label: 'ج.جداً'),
  (value: 'good', label: 'جيد'),
  (value: 'fair', label: 'مقبول'),
  (value: 'weak', label: 'ضعيف'),
];

/// Opens the "evaluate student" sheet. [student] carries student_id /
/// student_name plus any existing level values for [date]. Saves via
/// POST /teacher/evaluations/bulk-upsert. Returns `true` on success.
Future<bool?> showEvaluationForm({
  required BuildContext context,
  required TeacherApiService api,
  required String date, // YYYY-MM-DD
  required Map<String, dynamic> student,
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
        child: _EvaluationForm(api: api, date: date, student: student),
      ),
    ),
  );
}

class _EvaluationForm extends StatefulWidget {
  const _EvaluationForm(
      {required this.api, required this.date, required this.student});
  final TeacherApiService api;
  final String date;
  final Map<String, dynamic> student;

  @override
  State<_EvaluationForm> createState() => _EvaluationFormState();
}

class _EvaluationFormState extends State<_EvaluationForm> {
  final Map<String, String?> _levels = {};
  final _guidance = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final a in kEvalAxes) {
      final v = widget.student[a.key]?.toString();
      _levels[a.key] = (v != null && v.isNotEmpty) ? v : null;
    }
    _guidance.text = (widget.student['guidance'] ?? '').toString();
    _notes.text = (widget.student['notes'] ?? '').toString();
  }

  @override
  void dispose() {
    _guidance.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _setAll(String value) {
    setState(() {
      for (final a in kEvalAxes) {
        _levels[a.key] = value;
      }
    });
  }

  Future<void> _save() async {
    final missing = kEvalAxes.where((a) => _levels[a.key] == null).toList();
    if (missing.isNotEmpty) {
      Get.snackbar('تنبيه', 'حدّد كل المحاور الستة قبل الحفظ',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final item = <String, dynamic>{
      'student_id': widget.student['student_id'].toString(),
      for (final a in kEvalAxes) a.key: _levels[a.key],
      if (_guidance.text.trim().isNotEmpty) 'guidance': _guidance.text.trim(),
      if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
    };
    setState(() => _saving = true);
    try {
      await widget.api.bulkUpsertEvaluations({
        'eval_date': widget.date,
        'items': [item],
      });
      if (mounted) Navigator.pop(context, true);
      Get.snackbar('تم', 'تم حفظ التقييم',
          snackPosition: SnackPosition.BOTTOM);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      Get.snackbar('خطأ', 'تعذّر حفظ التقييم',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final name = (widget.student['student_name'] ?? '—').toString();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
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
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                        color: mq.accentSoft, borderRadius: MqRadius.brSm),
                    child: Icon(Icons.assignment_turned_in_outlined,
                        size: MqSize.iconSm, color: mq.accent),
                  ),
                  const SizedBox(width: MqSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('تقييم الطالب', style: context.text.bodySmall),
                        Text(name,
                            style: context.text.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
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
                ]),
                const SizedBox(height: MqSpacing.md),
                // Quick presets — set all axes at once.
                Wrap(
                  spacing: MqSpacing.sm,
                  runSpacing: MqSpacing.xs,
                  children: [
                    Text('تعبئة سريعة:',
                        style: context.text.labelSmall
                            ?.copyWith(color: mq.ink3)),
                    for (final l in kEvalLevels)
                      MqChip(
                        label: l.label,
                        selected: false,
                        onTap: () => _setAll(l.value),
                      ),
                  ],
                ),
                const Divider(height: MqSpacing.xl),
                for (final a in kEvalAxes) ...[
                  Text(a.label,
                      style: context.text.labelMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: MqSpacing.xs),
                  Wrap(
                    spacing: MqSpacing.xs,
                    runSpacing: MqSpacing.xs,
                    children: [
                      for (final l in kEvalLevels)
                        MqChip(
                          label: l.label,
                          selected: _levels[a.key] == l.value,
                          onTap: () =>
                              setState(() => _levels[a.key] = l.value),
                        ),
                    ],
                  ),
                  const SizedBox(height: MqSpacing.md),
                ],
                TextField(
                  controller: _guidance,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'توجيه (اختياري)',
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
                  label: _saving ? 'جارٍ الحفظ…' : 'حفظ التقييم',
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
}
