import 'package:flutter/material.dart';

import '../../../core/services/teacher_api_service.dart';
import '../shared/design/teacher_design.dart';
import '../shared/teacher_app_bar.dart';
import '../shared/teacher_helpers.dart' show initialsOf;

const Map<String, String> _kLevelAr = {
  'excellent': 'ممتاز',
  'very_good': 'جيد جداً',
  'good': 'جيد',
  'fair': 'مقبول',
  'weak': 'ضعيف',
};

const List<({String key, String label})> _kEvalAxes = [
  (key: 'scientific_level', label: 'علمي'),
  (key: 'behavioral_level', label: 'سلوكي'),
  (key: 'attendance_level', label: 'حضور'),
  (key: 'homework_preparation', label: 'واجب'),
  (key: 'participation_level', label: 'مشاركة'),
  (key: 'instruction_following', label: 'تعليمات'),
];

/// Teacher → full student profile within a course: the student's assignment
/// submissions, exam grades, and evaluations — aggregated client-side from the
/// per-resource endpoints (no unified backend report exists).
class TeacherStudentDetailScreen extends StatefulWidget {
  const TeacherStudentDetailScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.courseId,
    required this.assignments,
    required this.exams,
  });

  final String studentId;
  final String studentName;
  final String courseId;
  final List<Map<String, dynamic>> assignments;
  final List<Map<String, dynamic>> exams;

  @override
  State<TeacherStudentDetailScreen> createState() =>
      _TeacherStudentDetailScreenState();
}

class _TeacherStudentDetailScreenState
    extends State<TeacherStudentDetailScreen> {
  final _api = TeacherApiService();
  bool _loading = true;

  // assignment title -> {status, score, max}
  final List<Map<String, dynamic>> _assignmentRows = [];
  final List<Map<String, dynamic>> _examRows = [];
  List<Map<String, dynamic>> _evaluations = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final sid = widget.studentId;
    try {
      await Future.wait([
        _loadAssignments(sid),
        _loadExams(sid),
        _loadEvaluations(sid),
      ]);
    } catch (_) {
      // Each loader already isolates its own failures.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadAssignments(String sid) async {
    _assignmentRows.clear();
    final results = await Future.wait(widget.assignments.map((a) async {
      try {
        final res = await _api.fetchAssignmentOverview(a['id'].toString());
        final data = (res['data'] is Map)
            ? Map<String, dynamic>.from(res['data'])
            : <String, dynamic>{};
        final subs = (data['submissions'] is List)
            ? (data['submissions'] as List)
            : const [];
        Map<String, dynamic>? mine;
        for (final s in subs) {
          if (s is Map && (s['student_id'] ?? '').toString() == sid) {
            mine = Map<String, dynamic>.from(s);
            break;
          }
        }
        return {
          'title': (a['title'] ?? 'واجب').toString(),
          'max': a['max_score'],
          'score': mine?['score'],
          'received': mine != null && mine['submitted_at'] != null,
          'status': (mine?['status'] ?? '').toString(),
        };
      } catch (_) {
        return null;
      }
    }));
    _assignmentRows.addAll(results.whereType<Map<String, dynamic>>());
  }

  Future<void> _loadExams(String sid) async {
    _examRows.clear();
    final results = await Future.wait(widget.exams.map((e) async {
      try {
        final res = await _api.fetchExamStudents(e['id'].toString());
        final list = (res['data'] is List) ? (res['data'] as List) : const [];
        Map<String, dynamic>? mine;
        for (final s in list) {
          if (s is Map && (s['id'] ?? '').toString() == sid) {
            mine = Map<String, dynamic>.from(s);
            break;
          }
        }
        final type = (e['exam_type'] ?? '').toString();
        final desc = (e['description'] ?? '').toString();
        return {
          'title':
              desc.isNotEmpty ? desc : 'اختبار ${type == 'monthly' ? 'شهري' : 'يومي'}',
          'max': e['max_score'],
          'score': mine?['score'],
        };
      } catch (_) {
        return null;
      }
    }));
    _examRows.addAll(results.whereType<Map<String, dynamic>>());
  }

  Future<void> _loadEvaluations(String sid) async {
    try {
      final res = await _api.fetchEvaluationsByStudent(sid);
      final d = res['data'];
      _evaluations = (d is List)
          ? d.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
          : const [];
    } catch (_) {
      _evaluations = const [];
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
          return Scaffold(
            backgroundColor: mq.page,
            appBar: const TeacherAppBar(title: 'تفاصيل الطالب'),
            body: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    color: mq.accent,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                          MqSpacing.lg, MqSpacing.lg, MqSpacing.lg, MqSpacing.xl),
                      children: [
                        _headerCard(context),
                        const SizedBox(height: MqSpacing.lg),
                        _assignmentsCard(context),
                        const SizedBox(height: MqSpacing.md),
                        _examsCard(context),
                        const SizedBox(height: MqSpacing.md),
                        _evaluationsCard(context),
                      ],
                    ),
                  ),
          );
        }),
      ),
    );
  }

  Widget _headerCard(BuildContext context) {
    final mq = context.mq;
    final gradedA = _assignmentRows.where((r) => r['score'] != null).length;
    final gradedE = _examRows.where((r) => r['score'] != null).length;
    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.lg),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: mq.accentSoft,
            child: Text(initialsOf(widget.studentName),
                style: context.text.titleMedium?.copyWith(color: mq.accent)),
          ),
          const SizedBox(width: MqSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.studentName,
                    style: context.text.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                  'واجبات مُقيَّمة: $gradedA · اختبارات: $gradedE · تقييمات: ${_evaluations.length}',
                  style: context.text.labelSmall?.copyWith(color: mq.ink3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context,
      {required String title,
      required IconData icon,
      required List<Widget> children,
      required String emptyText}) {
    final mq = context.mq;
    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: MqSize.iconSm, color: mq.accent),
            const SizedBox(width: MqSpacing.sm),
            Text(title,
                style: context.text.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: MqSpacing.sm),
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: MqSpacing.sm),
              child: Text(emptyText,
                  style: context.text.bodySmall?.copyWith(color: mq.ink3)),
            )
          else
            ...children,
        ],
      ),
    );
  }

  Widget _scoreRow(BuildContext context, String title, dynamic score,
      dynamic max, String? statusLabel, MqBadgeTone tone) {
    final mq = context.mq;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium),
          ),
          const SizedBox(width: MqSpacing.sm),
          if (score != null)
            Text(max != null ? '$score / $max' : '$score',
                style: context.text.labelMedium?.copyWith(
                    color: mq.accent, fontWeight: FontWeight.w700))
          else
            MqBadge(label: statusLabel ?? 'لم يُقيَّم', tone: tone),
        ],
      ),
    );
  }

  Widget _assignmentsCard(BuildContext context) {
    return _section(
      context,
      title: 'الواجبات',
      icon: Icons.assignment_outlined,
      emptyText: 'لا توجد واجبات لهذا الكورس',
      children: [
        for (final r in _assignmentRows)
          _scoreRow(
            context,
            r['title'].toString(),
            r['score'],
            r['max'],
            (r['received'] == true) ? 'مُسلَّم' : 'لم يُسلَّم',
            (r['received'] == true) ? MqBadgeTone.accent : MqBadgeTone.neutral,
          ),
      ],
    );
  }

  Widget _examsCard(BuildContext context) {
    return _section(
      context,
      title: 'الاختبارات',
      icon: Icons.quiz_outlined,
      emptyText: 'لا توجد اختبارات لهذا الكورس',
      children: [
        for (final r in _examRows)
          _scoreRow(context, r['title'].toString(), r['score'], r['max'],
              'لم يُقيَّم', MqBadgeTone.neutral),
      ],
    );
  }

  Widget _evaluationsCard(BuildContext context) {
    final mq = context.mq;
    return _section(
      context,
      title: 'التقييمات',
      icon: Icons.assignment_turned_in_outlined,
      emptyText: 'لا توجد تقييمات لهذا الطالب',
      children: [
        for (final e in _evaluations)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: MqSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_date(e['eval_date'] ?? e['eval_date_date']),
                    style: context.text.labelMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: MqSpacing.xs,
                  runSpacing: MqSpacing.xxs,
                  children: [
                    for (final a in _kEvalAxes)
                      if ((e[a.key] ?? '').toString().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: mq.fill2,
                            borderRadius: MqRadius.brPill,
                          ),
                          child: Text(
                            '${a.label}: ${_kLevelAr[e[a.key].toString()] ?? e[a.key]}',
                            style: context.text.labelSmall
                                ?.copyWith(color: mq.ink2),
                          ),
                        ),
                  ],
                ),
                if ((e['notes'] ?? '').toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('ملاحظة: ${e['notes']}',
                      style: context.text.labelSmall
                          ?.copyWith(color: mq.ink3)),
                ],
                const Divider(height: MqSpacing.lg),
              ],
            ),
          ),
      ],
    );
  }
}
