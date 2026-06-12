import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:get/get.dart';

import '../../../core/services/teacher_api_service.dart';
import '../shared/design/teacher_design.dart';
import '../shared/teacher_app_bar.dart';
import '../shared/teacher_helpers.dart' show initialsOf;
import 'teacher_exam_form.dart';

/// Teacher → exam detail. Shows the exam header with edit/delete, then the
/// roster of targeted students (from the exam's sessions ∪ course) where each
/// student can be given a grade (validated against max_score).
class TeacherExamDetailScreen extends StatefulWidget {
  const TeacherExamDetailScreen({
    super.key,
    required this.examId,
    required this.courseId,
    required this.exam,
  });

  final String examId;
  final String courseId;
  final Map<String, dynamic> exam;

  @override
  State<TeacherExamDetailScreen> createState() =>
      _TeacherExamDetailScreenState();
}

class _TeacherExamDetailScreenState extends State<TeacherExamDetailScreen> {
  final _api = TeacherApiService();

  bool _loading = true;
  bool _changed = false;
  late Map<String, dynamic> _exam;
  List<Map<String, dynamic>> _students = []; // {id, name, score, ...}
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _exam = Map<String, dynamic>.from(widget.exam);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.fetchExamById(widget.examId),
        _api.fetchExamStudents(widget.examId),
      ]);
      final examData = results[0]['data'];
      if (examData is Map) _exam = Map<String, dynamic>.from(examData);
      _students = _mapList(results[1]['data']);
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّر تحميل تفاصيل الاختبار',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _mapList(Object? v) {
    if (v is List) {
      return v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    }
    if (v is Map && v['items'] is List) {
      return (v['items'] as List)
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return const [];
  }

  num? get _maxScore {
    final v = _exam['max_score'];
    if (v is num) return v;
    return num.tryParse('${v ?? ''}');
  }

  num? _scoreOf(Map<String, dynamic> s) {
    final v = s['score'];
    if (v is num) return v;
    return num.tryParse('${v ?? ''}');
  }

  Future<void> _gradeSheet(Map<String, dynamic> student) async {
    final id = student['id'].toString();
    final scoreCtl =
        TextEditingController(text: (_scoreOf(student) ?? '').toString());
    final max = _maxScore;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Theme(
        data: isDark ? MqTheme.dark() : MqTheme.light(),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Builder(builder: (sheetCtx) {
            final mq = sheetCtx.mq;
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: mq.card,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(MqRadius.xl)),
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(MqSpacing.lg,
                        MqSpacing.sm, MqSpacing.lg, MqSpacing.lg),
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
                                color: mq.accentSoft,
                                borderRadius: MqRadius.brSm),
                            child: Icon(Icons.grade_outlined,
                                size: MqSize.iconSm, color: mq.accent),
                          ),
                          const SizedBox(width: MqSpacing.sm),
                          Expanded(
                            child: Text('درجة ${student['name']}',
                                style: sheetCtx.text.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          InkWell(
                            onTap: () => Navigator.pop(sheetCtx, false),
                            customBorder: const CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child:
                                  Icon(Icons.close_rounded, color: mq.ink3),
                            ),
                          ),
                        ]),
                        const SizedBox(height: MqSpacing.lg),
                        TextField(
                          controller: scoreCtl,
                          autofocus: true,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: false, signed: false),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: InputDecoration(
                            labelText:
                                max != null ? 'الدرجة (من $max)' : 'الدرجة',
                            prefixIcon: const Icon(Icons.grade_outlined),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: MqSpacing.xl),
                        MqButton(
                          label: 'حفظ الدرجة',
                          icon: Icons.check_rounded,
                          onPressed: () => Navigator.pop(sheetCtx, true),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );

    if (saved == true) {
      final score = num.tryParse(scoreCtl.text.trim());
      if (score == null) {
        Get.snackbar('تنبيه', 'أدخل درجة صحيحة',
            snackPosition: SnackPosition.BOTTOM);
      } else if (max != null && score > max) {
        Get.snackbar('تنبيه', 'الدرجة يجب ألا تتجاوز $max',
            snackPosition: SnackPosition.BOTTOM);
      } else {
        await _submitGrade(id, score);
      }
    }
    Future.delayed(const Duration(milliseconds: 500), scoreCtl.dispose);
  }

  Future<void> _submitGrade(String studentId, num score) async {
    setState(() => _busy.add(studentId));
    try {
      await _api.gradeExam(widget.examId, studentId, score);
      final idx =
          _students.indexWhere((s) => s['id'].toString() == studentId);
      if (idx >= 0) _students[idx] = {..._students[idx], 'score': score};
      _changed = true;
      Get.snackbar('تم', 'تم حفظ الدرجة',
          snackPosition: SnackPosition.BOTTOM);
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّر حفظ الدرجة',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _busy.remove(studentId));
    }
  }

  Future<void> _edit() async {
    final saved = await showExamForm(
      context: context,
      courseId: widget.courseId,
      api: _api,
      existing: _exam,
    );
    if (saved == true) {
      _changed = true;
      _load();
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الاختبار'),
        content: const Text('سيتم حذف الاختبار ودرجاته. لا يمكن التراجع. متابعة؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteExam(widget.examId);
      if (mounted) Navigator.pop(context, true);
      Get.snackbar('تم', 'تم حذف الاختبار',
          snackPosition: SnackPosition.BOTTOM);
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّر حذف الاختبار',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  String _dateTime(dynamic raw) {
    final d = DateTime.tryParse((raw ?? '').toString());
    if (d == null) return '';
    final l = d.toLocal();
    final date =
        '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
    final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
    final m = l.minute.toString().padLeft(2, '0');
    final ap = l.hour < 12 ? 'ص' : 'م';
    return '$date · $h:$m $ap';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: isDark ? MqTheme.dark() : MqTheme.light(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(builder: (context) {
          final mq = context.mq;
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && mounted) Navigator.pop(context, _changed);
            },
            child: Scaffold(
              backgroundColor: mq.page,
              appBar: TeacherAppBar(
                title: 'تفاصيل الاختبار',
                actions: [
                  IconButton(
                    tooltip: 'تعديل',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: _edit,
                  ),
                  IconButton(
                    tooltip: 'حذف',
                    icon: Icon(Icons.delete_outline, color: mq.error),
                    onPressed: _delete,
                  ),
                ],
              ),
              body: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: mq.accent,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(MqSpacing.lg,
                            MqSpacing.lg, MqSpacing.lg, MqSpacing.xl),
                        children: [
                          _headerCard(context),
                          const SizedBox(height: MqSpacing.lg),
                          Row(
                            children: [
                              Text('الطلاب', style: context.text.titleSmall),
                              const Spacer(),
                              Text('${_students.length}',
                                  style: context.text.labelMedium
                                      ?.copyWith(color: mq.ink3)),
                            ],
                          ),
                          const SizedBox(height: MqSpacing.sm),
                          if (_students.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(MqSpacing.xl),
                              child: Center(
                                child: Text('لا يوجد طلاب لهذا الاختبار',
                                    style: context.text.bodyMedium
                                        ?.copyWith(color: mq.ink2)),
                              ),
                            )
                          else
                            for (final s in _students)
                              Padding(
                                padding: const EdgeInsets.only(
                                    bottom: MqSpacing.sm),
                                child: _studentRow(context, s),
                              ),
                        ],
                      ),
                    ),
            ),
          );
        }),
      ),
    );
  }

  Widget _headerCard(BuildContext context) {
    final mq = context.mq;
    final e = _exam;
    final type = (e['exam_type'] ?? '').toString();
    final typeLabel = type == 'monthly' ? 'شهري' : 'يومي';
    final desc = (e['description'] ?? '').toString();
    final title = desc.isNotEmpty ? desc : 'اختبار $typeLabel';
    final when = _dateTime(e['exam_date']);
    final notes = (e['notes'] ?? '').toString();
    final sessions = (e['sessions'] is List) ? (e['sessions'] as List) : const [];

    Widget chip(IconData icon, String text) => Container(
          padding: const EdgeInsets.symmetric(
              horizontal: MqSpacing.sm, vertical: 4),
          decoration: BoxDecoration(
              color: mq.orangeSoft, borderRadius: MqRadius.brPill),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: mq.orange),
            const SizedBox(width: 4),
            Text(text,
                style: context.text.labelSmall?.copyWith(color: mq.orange)),
          ]),
        );

    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: context.text.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              MqBadge(label: typeLabel, tone: MqBadgeTone.orange),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(notes,
                style: context.text.bodySmall?.copyWith(color: mq.ink2)),
          ],
          const SizedBox(height: MqSpacing.md),
          Wrap(
            spacing: MqSpacing.sm,
            runSpacing: MqSpacing.sm,
            children: [
              if (when.isNotEmpty) chip(Icons.event_outlined, when),
              if (_maxScore != null)
                chip(Icons.grade_outlined, 'الدرجة القصوى: $_maxScore'),
              if (sessions.isNotEmpty)
                chip(Icons.link_rounded, '${sessions.length} جلسة مرتبطة'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _studentRow(BuildContext context, Map<String, dynamic> s) {
    final mq = context.mq;
    final id = s['id'].toString();
    final name = (s['name'] ?? '—').toString();
    final score = _scoreOf(s);
    final busy = _busy.contains(id);
    final max = _maxScore;

    return MqCard(
      padding: const EdgeInsets.symmetric(
          horizontal: MqSpacing.md, vertical: MqSpacing.sm),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: mq.accentSoft,
            child: Text(initialsOf(name),
                style: context.text.labelSmall
                    ?.copyWith(color: mq.accent, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: MqSpacing.sm),
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: MqSpacing.sm),
          InkWell(
            onTap: busy ? null : () => _gradeSheet(s),
            borderRadius: MqRadius.brPill,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: mq.accentSoft,
                borderRadius: MqRadius.brPill,
                border: Border.all(color: mq.accentLine),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                busy
                    ? const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.grade_outlined, size: 14, color: mq.accent),
                const SizedBox(width: 4),
                Text(
                  score != null
                      ? (max != null ? 'الدرجة: $score/$max' : 'الدرجة: $score')
                      : 'إضافة درجة',
                  style: context.text.labelSmall
                      ?.copyWith(color: mq.accent, fontWeight: FontWeight.w700),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
