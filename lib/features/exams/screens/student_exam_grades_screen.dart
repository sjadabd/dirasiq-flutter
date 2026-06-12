// Student → Grades & reports (MulhimIQ design-system pass).
//
// Opened from Course Hub → الأكاديمي → الدرجات والتقارير. Backed by the existing
// endpoint ApiService.fetchStudentExamReportByType(type: 'monthly') — no backend
// change. The report has no per-item detail route; it's a read-only summary.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';

class StudentExamGradesScreen extends StatefulWidget {
  const StudentExamGradesScreen({super.key});

  @override
  State<StudentExamGradesScreen> createState() => _StudentExamGradesScreenState();
}

class _StudentExamGradesScreenState extends State<StudentExamGradesScreen> {
  final _api = ApiService();
  bool _loading = false;
  String? _error;
  final String _reportType = 'monthly';
  dynamic _report;

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  List<Map<String, dynamic>> _safeListOfMaps(dynamic v) {
    if (v is List) {
      try {
        return v.whereType<Map<String, dynamic>>().map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {
        return const [];
      }
    }
    return const [];
  }

  Map<String, dynamic> _safeMap(dynamic v) {
    if (v is Map) {
      try {
        return Map<String, dynamic>.from(v);
      } catch (_) {
        return const {};
      }
    }
    return const {};
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      return DateFormat('dd/MM/yyyy', 'ar').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }

  Future<void> _fetchReport() async {
    setState(() {
      _loading = true;
      _error = null;
      _report = null;
    });
    try {
      final report = await _api.fetchStudentExamReportByType(type: _reportType);
      setState(() => _report = report);
    } catch (e) {
      setState(() => _error = 'تعذّر تحميل الدرجات');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dsTheme = isDark ? MqTheme.dark() : MqTheme.light();

    return Theme(
      data: dsTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) => Scaffold(
            backgroundColor: context.mq.page,
            appBar: AppBar(title: const Text('الدرجات والتقارير')),
            body: RefreshIndicator(onRefresh: _fetchReport, child: _body(context)),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) return _skeleton(context);
    if (_error != null) return _errorView(context);

    final isList = _report is List;
    final items = isList ? _safeListOfMaps(_report) : const <Map<String, dynamic>>[];
    final single = !isList ? _safeMap(_report) : const <String, dynamic>{};
    final empty = _report == null || (isList && items.isEmpty) || (!isList && single.isEmpty);

    if (empty) return _empty(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.lg, MqSpacing.lg, MqSpacing.xxxl),
      children: [
        _header(context),
        MqSpacing.gapLg,
        if (isList)
          for (final it in items)
            Padding(padding: const EdgeInsets.only(bottom: MqSpacing.sm), child: _gradeCard(context, it))
        else
          _reportCard(context, single),
      ],
    );
  }

  Widget _header(BuildContext context) {
    final mq = context.mq;
    return Container(
      padding: const EdgeInsets.all(MqSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [mq.accent, mq.accentDeep]),
        borderRadius: MqRadius.brXl,
        boxShadow: [BoxShadow(color: mq.accentShadow, blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(MqSpacing.sm),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: MqRadius.brMd),
            child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 22),
          ),
          MqSpacing.gapMd,
          Expanded(
            child: Text('تقرير الامتحانات الشهرية',
                style: context.text.titleSmall?.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  ({double? pct, MqBadgeTone tone, String? result}) _result(String score, String maxScore) {
    final s = double.tryParse(score);
    final m = double.tryParse(maxScore);
    if (s == null || m == null || m <= 0) return (pct: null, tone: MqBadgeTone.neutral, result: null);
    final pct = (s / m) * 100;
    final pass = pct >= 50;
    return (pct: pct, tone: pass ? MqBadgeTone.success : MqBadgeTone.error, result: pass ? 'ناجح' : 'دون المعدّل');
  }

  Widget _gradeCard(BuildContext context, Map<String, dynamic> it) {
    final mq = context.mq;
    final exam = _safeMap(it['exam']);
    final grade = _safeMap(it['grade']);
    final name = (exam['title']?.toString().trim().isNotEmpty ?? false)
        ? exam['title'].toString()
        : (exam['description']?.toString().trim().isNotEmpty ?? false)
            ? exam['description'].toString()
            : 'امتحان شهري';
    final maxScore = exam['max_score']?.toString() ?? '-';
    final score = grade['score']?.toString() ?? '-';
    final type = (exam['exam_type'] ?? 'monthly').toString();
    final course = (exam['course_name'] ?? exam['subject_name'] ?? '').toString();
    final dateRaw = (exam['exam_date'] ?? exam['date'] ?? exam['created_at'] ?? '').toString();
    final r = _result(score, maxScore);

    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: mq.accentSoft, borderRadius: MqRadius.brMd),
                child: Icon(Icons.assessment_outlined, size: MqSize.iconSm, color: mq.accent),
              ),
              MqSpacing.gapSm,
              Expanded(child: Text(name, style: context.text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis)),
              MqSpacing.gapXs,
              _scorePill(context, score, maxScore, r.tone),
            ],
          ),
          MqSpacing.gapSm,
          Wrap(
            spacing: MqSpacing.xs,
            runSpacing: MqSpacing.xxs,
            children: [
              if (r.result != null) MqBadge(label: r.result!, tone: r.tone, solid: true),
              if (r.pct != null) MqBadge(label: '${r.pct!.toStringAsFixed(0)}%', tone: r.tone),
              MqBadge(label: type == 'monthly' ? 'شهري' : (type == 'daily' ? 'يومي' : type), tone: MqBadgeTone.neutral),
              if (course.isNotEmpty) MqBadge(label: course, tone: MqBadgeTone.neutral, icon: Icons.class_outlined),
              if (dateRaw.isNotEmpty) MqBadge(label: _formatDate(dateRaw), tone: MqBadgeTone.neutral, icon: Icons.event_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scorePill(BuildContext context, String score, String maxScore, MqBadgeTone tone) {
    final mq = context.mq;
    final c = switch (tone) {
      MqBadgeTone.success => mq.success,
      MqBadgeTone.error => mq.error,
      _ => mq.accent,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: MqSpacing.sm, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: MqRadius.brPill),
      child: Text('$score / $maxScore', style: context.text.labelMedium?.copyWith(color: c, fontWeight: FontWeight.w800)),
    );
  }

  Widget _reportCard(BuildContext context, Map<String, dynamic> r) {
    final subject = (r['subject_name'] ?? '').toString();
    final course = (r['course_name'] ?? '').toString();
    final maxScore = (r['max_score'] ?? '').toString();
    final studentScore = (r['student_score'] ?? '-').toString();
    final description = (r['description'] ?? '').toString().trim();
    final notes = (r['notes'] ?? '').toString().trim();
    final examType = (r['exam_type'] ?? '').toString();
    final dateRaw = (r['exam_date'] ?? r['date'] ?? '').toString();
    final res = _result(studentScore, maxScore);

    return MqCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(subject.isNotEmpty ? subject : 'تقرير الامتحان', style: context.text.titleMedium)),
              MqSpacing.gapXs,
              _scorePill(context, studentScore, maxScore, res.tone),
            ],
          ),
          MqSpacing.gapSm,
          Wrap(
            spacing: MqSpacing.xs,
            runSpacing: MqSpacing.xxs,
            children: [
              if (res.result != null) MqBadge(label: res.result!, tone: res.tone, solid: true),
              if (res.pct != null) MqBadge(label: 'النسبة ${res.pct!.toStringAsFixed(1)}%', tone: res.tone),
              if (examType.isNotEmpty) MqBadge(label: examType == 'monthly' ? 'شهري' : examType, tone: MqBadgeTone.neutral),
              if (course.isNotEmpty) MqBadge(label: course, tone: MqBadgeTone.neutral, icon: Icons.class_outlined),
              if (dateRaw.isNotEmpty) MqBadge(label: _formatDate(dateRaw), tone: MqBadgeTone.neutral, icon: Icons.event_outlined),
            ],
          ),
          if (description.isNotEmpty) ...[
            const Divider(height: MqSpacing.xl),
            Text('الوصف', style: context.text.labelMedium),
            MqSpacing.gapXs,
            Text(description, style: context.text.bodySmall?.copyWith(height: 1.4)),
          ],
          if (notes.isNotEmpty) ...[
            MqSpacing.gapSm,
            Text('الملاحظات', style: context.text.labelMedium),
            MqSpacing.gapXs,
            Text(notes, style: context.text.bodySmall?.copyWith(height: 1.4)),
          ],
        ],
      ),
    );
  }

  // ── states ──────────────────────────────────────────────────────────────────

  Widget _empty(BuildContext context) {
    final mq = context.mq;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MqSpacing.lg),
      children: [
        const SizedBox(height: MqSpacing.xxl),
        Center(child: Column(children: [
          Container(
            padding: const EdgeInsets.all(MqSpacing.lg),
            decoration: BoxDecoration(color: mq.accentSoft, shape: BoxShape.circle),
            child: Icon(Icons.bar_chart_rounded, size: 44, color: mq.accent),
          ),
          MqSpacing.gapMd,
          Text('لا توجد درجات بعد', style: context.text.titleMedium),
          MqSpacing.gapXs,
          Text('ستظهر هنا درجاتك في الامتحانات الشهرية.', textAlign: TextAlign.center, style: context.text.bodySmall),
        ])),
      ],
    );
  }

  Widget _errorView(BuildContext context) {
    final mq = context.mq;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MqSpacing.lg),
      children: [
        const SizedBox(height: MqSpacing.xxl),
        Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off_rounded, size: 44, color: mq.error),
          MqSpacing.gapMd,
          Text(_error ?? 'حدث خطأ', textAlign: TextAlign.center, style: context.text.bodyMedium),
          MqSpacing.gapMd,
          MqButton(label: 'إعادة المحاولة', icon: Icons.refresh_rounded, expand: false, onPressed: _fetchReport),
        ])),
      ],
    );
  }

  Widget _skeleton(BuildContext context) {
    final mq = context.mq;
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.lg, MqSpacing.lg, MqSpacing.lg),
      children: [
        Container(height: 64, decoration: BoxDecoration(color: mq.fill2, borderRadius: MqRadius.brXl)),
        MqSpacing.gapLg,
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: MqSpacing.sm),
            child: MqCard(
              padding: const EdgeInsets.all(MqSpacing.md),
              child: Row(children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: mq.fill2, borderRadius: MqRadius.brMd)),
                MqSpacing.gapSm,
                Expanded(child: Container(height: 14, decoration: BoxDecoration(color: mq.fill2, borderRadius: MqRadius.brSm))),
              ]),
            ),
          ),
      ],
    );
  }
}
