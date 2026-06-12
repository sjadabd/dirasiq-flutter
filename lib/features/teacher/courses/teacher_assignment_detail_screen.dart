import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:get/get.dart';

import '../../../core/services/teacher_api_service.dart';
import '../shared/design/teacher_design.dart';
import '../shared/teacher_app_bar.dart';
import '../shared/teacher_helpers.dart' show initialsOf;
import 'teacher_assignment_form.dart';

/// Teacher → assignment detail. Shows the assignment header with edit/delete,
/// then a per-student roster where each student can be marked "received" (✓)
/// and given a grade. Backed by GET /teacher/assignments/:id/overview plus the
/// per-student received + grade endpoints.
class TeacherAssignmentDetailScreen extends StatefulWidget {
  const TeacherAssignmentDetailScreen({
    super.key,
    required this.assignmentId,
    required this.courseId,
    required this.assignment,
  });

  final String assignmentId;
  final String courseId;
  final Map<String, dynamic> assignment;

  @override
  State<TeacherAssignmentDetailScreen> createState() =>
      _TeacherAssignmentDetailScreenState();
}

class _TeacherAssignmentDetailScreenState
    extends State<TeacherAssignmentDetailScreen> {
  final _api = TeacherApiService();

  bool _loading = true;
  bool _changed = false; // tells the caller to refresh its list
  late Map<String, dynamic> _assignment;
  List<Map<String, dynamic>> _students = []; // {id, name}
  final Map<String, Map<String, dynamic>> _subByStudent = {}; // studentId -> submission
  final Set<String> _busy = {}; // studentIds with an in-flight action

  @override
  void initState() {
    super.initState();
    _assignment = Map<String, dynamic>.from(widget.assignment);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.fetchAssignmentOverview(widget.assignmentId),
        _api.fetchStudentsByCourse(widget.courseId),
      ]);
      final data = (results[0]['data'] is Map)
          ? Map<String, dynamic>.from(results[0]['data'])
          : <String, dynamic>{};
      if (data['assignment'] is Map) {
        _assignment = Map<String, dynamic>.from(data['assignment']);
      }
      final recipients = _mapList(data['recipients']);
      final submissions = _mapList(data['submissions']);
      final courseStudents = _mapList(results[1]['data']);

      _subByStudent.clear();
      for (final s in submissions) {
        final sid = (s['student_id'] ?? '').toString();
        if (sid.isNotEmpty) _subByStudent[sid] = s;
      }

      final specific =
          (_assignment['visibility'] ?? '').toString() == 'specific_students';
      if (specific && recipients.isNotEmpty) {
        _students = recipients
            .map((r) => {
                  'id': (r['id'] ?? r['student_id'] ?? '').toString(),
                  'name': (r['name'] ?? r['student_name'] ?? '—').toString(),
                })
            .toList();
      } else {
        _students = courseStudents
            .map((s) => {
                  'id': (s['student_id'] ?? s['id'] ?? '').toString(),
                  'name': (s['student_name'] ?? s['name'] ?? '—').toString(),
                })
            .toList();
      }
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّر تحميل تفاصيل الواجب',
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

  bool _received(String studentId) {
    final s = _subByStudent[studentId];
    return s != null && (s['submitted_at'] != null);
  }

  num? _score(String studentId) {
    final s = _subByStudent[studentId];
    final v = s?['score'];
    if (v is num) return v;
    return num.tryParse('${v ?? ''}');
  }

  Future<void> _toggleReceived(String studentId) async {
    final next = !_received(studentId);
    setState(() => _busy.add(studentId));
    try {
      final res =
          await _api.markAssignmentReceived(widget.assignmentId, studentId, next);
      final sub = (res['data'] is Map)
          ? Map<String, dynamic>.from(res['data'])
          : {'submitted_at': next ? DateTime.now().toIso8601String() : null};
      _subByStudent[studentId] = {...?_subByStudent[studentId], ...sub};
      _changed = true;
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّر تحديث الاستلام',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _busy.remove(studentId));
    }
  }

  Future<void> _gradeSheet(Map<String, dynamic> student) async {
    final id = student['id'].toString();
    final scoreCtl =
        TextEditingController(text: (_score(id) ?? '').toString());
    final fbCtl = TextEditingController(
        text: (_subByStudent[id]?['feedback'] ?? '').toString());
    final max = _assignment['max_score'];
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
                            labelText: max != null ? 'الدرجة (من $max)' : 'الدرجة',
                            prefixIcon: const Icon(Icons.grade_outlined),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: MqSpacing.md),
                        TextField(
                          controller: fbCtl,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'ملاحظة للطالب (اختياري)',
                            alignLabelWithHint: true,
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
      } else {
        await _submitGrade(id, score, fbCtl.text.trim());
      }
    }
    // Delay disposal so the sheet's TextFields aren't torn down mid-dismiss
    // (avoids the `_dependents.isEmpty` assertion).
    Future.delayed(const Duration(milliseconds: 500), () {
      scoreCtl.dispose();
      fbCtl.dispose();
    });
  }

  Future<void> _submitGrade(String studentId, num score, String feedback) async {
    setState(() => _busy.add(studentId));
    try {
      final res = await _api.gradeAssignment(widget.assignmentId, studentId,
          score: score, feedback: feedback);
      final sub = (res['data'] is Map)
          ? Map<String, dynamic>.from(res['data'])
          : {'score': score, 'feedback': feedback};
      _subByStudent[studentId] = {...?_subByStudent[studentId], ...sub};
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
    final saved = await showAssignmentForm(
      context: context,
      courseId: widget.courseId,
      api: _api,
      existing: _assignment,
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
        title: const Text('حذف الواجب'),
        content: const Text(
            'سيتم حذف الواجب وإشعار الطلاب. لا يمكن التراجع. متابعة؟'),
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
      await _api.deleteAssignment(widget.assignmentId);
      if (mounted) Navigator.pop(context, true);
      Get.snackbar('تم', 'تم حذف الواجب',
          snackPosition: SnackPosition.BOTTOM);
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّر حذف الواجب',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  String _date(dynamic raw) {
    final s = (raw ?? '').toString();
    return s.length >= 10 ? s.substring(0, 10) : s;
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
                title: 'تفاصيل الواجب',
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
                                child: Text('لا يوجد طلاب لهذا الواجب',
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
    final a = _assignment;
    final title = (a['title'] ?? 'واجب').toString();
    final desc = (a['description'] ?? '').toString();
    final due = _date(a['due_date']);
    final assigned = _date(a['assigned_date']);
    final score = a['max_score'];
    final active = a['is_active'] == true || a['is_active'] == 1;
    final specific = (a['visibility'] ?? '').toString() == 'specific_students';

    Widget chip(IconData icon, String text) => Container(
          padding: const EdgeInsets.symmetric(
              horizontal: MqSpacing.sm, vertical: 4),
          decoration: BoxDecoration(
            color: mq.accentSoft,
            borderRadius: MqRadius.brPill,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: mq.accent),
            const SizedBox(width: 4),
            Text(text,
                style: context.text.labelSmall?.copyWith(color: mq.accent)),
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
              MqBadge(
                label: active ? 'مفعّل' : 'موقوف',
                tone: active ? MqBadgeTone.success : MqBadgeTone.neutral,
              ),
            ],
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(desc,
                style: context.text.bodySmall?.copyWith(color: mq.ink2)),
          ],
          const SizedBox(height: MqSpacing.md),
          Wrap(
            spacing: MqSpacing.sm,
            runSpacing: MqSpacing.sm,
            children: [
              if (assigned.isNotEmpty)
                chip(Icons.event_outlined, 'الإسناد: $assigned'),
              if (due.isNotEmpty)
                chip(Icons.event_available_outlined, 'التسليم: $due'),
              if (score != null) chip(Icons.grade_outlined, 'الدرجة: $score'),
              chip(specific ? Icons.group_outlined : Icons.groups_outlined,
                  specific ? 'طلاب محدّدون' : 'كل الطلاب'),
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
    final received = _received(id);
    final score = _score(id);
    final busy = _busy.contains(id);

    return MqCard(
      padding: const EdgeInsets.symmetric(
          horizontal: MqSpacing.md, vertical: MqSpacing.sm),
      // Compact controls sit opposite the name on the trailing edge.
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
          _pill(
            context,
            icon: Icons.star_rounded,
            label: score != null ? '$score' : 'درجة',
            color: mq.accent,
            bg: mq.accentSoft,
            border: mq.accentLine,
            busy: busy,
            onTap: busy ? null : () => _gradeSheet(s),
          ),
          const SizedBox(width: MqSpacing.xs),
          _pill(
            context,
            icon:
                received ? Icons.check_circle : Icons.radio_button_unchecked,
            label: received ? 'مُستلَم' : 'استلام',
            color: received ? context.teacher.success : mq.ink2,
            bg: received
                ? context.teacher.success.withValues(alpha: 0.12)
                : mq.fill2,
            border: received
                ? context.teacher.success.withValues(alpha: 0.5)
                : mq.line,
            busy: busy,
            onTap: busy ? null : () => _toggleReceived(id),
          ),
        ],
      ),
    );
  }

  Widget _pill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required Color bg,
    required Color border,
    required bool busy,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: MqRadius.brPill,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: MqRadius.brPill,
          border: Border.all(color: border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          busy
              ? const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(icon, size: 14, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: context.text.labelSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
