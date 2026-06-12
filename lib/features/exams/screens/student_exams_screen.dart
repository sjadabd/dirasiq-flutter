// Student → Exams list (MulhimIQ design-system pass).
//
// Opened from Course Hub → الأكاديمي → الامتحانات with fixedType: 'daily'.
// Backed by existing endpoints (no backend change):
//   • fetchStudentExams(page, limit, type)      → list
//   • fetchStudentExamById(id) + fetchStudentExamMyGrade(id) → details dialog
//
// The list items carry: title, subject_name, course_name, max_score, date,
// description, notes. They do NOT carry teacher name or the student's score
// (the score is fetched per-exam for the details dialog) — those are hidden
// on the cards, shown in the dialog when available.

import 'package:flutter/material.dart';

import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';

class StudentExamsScreen extends StatefulWidget {
  final String fixedType; // 'daily' or 'monthly'
  final String? title;
  const StudentExamsScreen({super.key, required this.fixedType, this.title});

  @override
  State<StudentExamsScreen> createState() => _StudentExamsScreenState();
}

class _StudentExamsScreenState extends State<StudentExamsScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  int _page = 1;
  final int _limit = 10;
  late String _type;
  List<Map<String, dynamic>> _items = [];
  bool _hasMore = true;
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _type = widget.fixedType;
    _fetch(reset: true);
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loading) return;
    if (_controller.position.pixels >= _controller.position.maxScrollExtent - 200) {
      _fetch();
    }
  }

  Future<void> _fetch({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
        _items = [];
        _hasMore = true;
      });
    }
    try {
      final res = await _api.fetchStudentExams(page: _page, limit: _limit, type: _type);
      final data = res['data'];
      final list = (data is List) ? List<Map<String, dynamic>>.from(data) : <Map<String, dynamic>>[];
      setState(() {
        _items.addAll(list);
        _hasMore = list.length == _limit;
        _page += 1;
      });
    } catch (e) {
      setState(() => _error = 'تعذّر تحميل الامتحانات');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async => _fetch(reset: true);

  DateTime? _examDate(Map<String, dynamic> e) {
    final raw = (e['date'] ?? e['exam_date'] ?? e['examDate'] ?? e['created_at'])?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
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
            appBar: AppBar(title: Text(widget.title ?? 'الامتحانات')),
            body: RefreshIndicator(onRefresh: _refresh, child: _body(context)),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading && _items.isEmpty) return _skeleton();
    if (_error != null && _items.isEmpty) return _errorView(context);
    if (_items.isEmpty) return _empty(context);

    return ListView.separated(
      controller: _controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.md, MqSpacing.lg, MqSpacing.xxxl),
      itemCount: _items.length + (_loading ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: MqSpacing.sm),
      itemBuilder: (context, i) {
        if (i == _items.length) {
          return const Padding(
            padding: EdgeInsets.all(MqSpacing.md),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return _card(context, _items[i]);
      },
    );
  }

  Widget _card(BuildContext context, Map<String, dynamic> e) {
    final mq = context.mq;
    final title = (e['title'] ?? e['name'] ?? 'امتحان').toString();
    final type = (e['type'] ?? _type).toString();
    final subject = (e['subject_name'] ?? '').toString();
    final course = (e['course_name'] ?? '').toString();
    final maxScore = (e['max_score'] ?? e['maxScore'] ?? '').toString();
    final desc = (e['description'] ?? '').toString().trim();
    final date = _examDate(e);
    final typeLabel = type == 'monthly' ? 'شهري' : (type == 'daily' ? 'يومي' : type);

    final ({String label, MqBadgeTone tone})? statusBadge = date == null
        ? null
        : date.isBefore(DateTime.now())
            ? (label: 'منتهٍ', tone: MqBadgeTone.neutral)
            : (label: 'قادم', tone: MqBadgeTone.accent);

    return MqCard(
      onTap: () => _openExamDetails(e['id']?.toString()),
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: mq.accentSoft, borderRadius: MqRadius.brMd),
                child: Icon(Icons.quiz_outlined, color: mq.accent, size: MqSize.iconMd),
              ),
              MqSpacing.gapMd,
              Expanded(
                child: Text(title, style: context.text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              if (statusBadge != null) ...[MqSpacing.gapXs, MqBadge(label: statusBadge.label, tone: statusBadge.tone)],
            ],
          ),
          MqSpacing.gapSm,
          Wrap(
            spacing: MqSpacing.xs,
            runSpacing: MqSpacing.xxs,
            children: [
              MqBadge(label: typeLabel, tone: MqBadgeTone.accent),
              if (subject.isNotEmpty) MqBadge(label: subject, tone: MqBadgeTone.neutral, icon: Icons.menu_book_outlined),
              if (course.isNotEmpty) MqBadge(label: course, tone: MqBadgeTone.neutral, icon: Icons.class_outlined),
              if (maxScore.isNotEmpty) MqBadge(label: 'الدرجة $maxScore', tone: MqBadgeTone.orange, icon: Icons.grade_outlined),
            ],
          ),
          if (desc.isNotEmpty) ...[
            MqSpacing.gapSm,
            Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
          ],
          if (date != null) ...[
            MqSpacing.gapSm,
            Row(children: [
              Icon(Icons.event_outlined, size: 13, color: mq.ink3),
              MqSpacing.gapXxs,
              Text(_formatDate(date), style: context.text.labelSmall),
            ]),
          ],
          MqSpacing.gapMd,
          MqButton(label: 'عرض التفاصيل', size: MqButtonSize.small, onPressed: () => _openExamDetails(e['id']?.toString())),
        ],
      ),
    );
  }

  // ── details dialog (existing data flow, restyled) ──────────────────────────

  Future<void> _openExamDetails(String? id) async {
    if (id == null || id.isEmpty) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
    );
    try {
      final details = await _api.fetchStudentExamById(id);
      Map<String, dynamic>? my;
      try {
        my = await _api.fetchStudentExamMyGrade(id);
      } catch (_) {
        my = null;
      }
      if (!mounted) return;
      Navigator.pop(context);
      _showExamDialog(details, my);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  void _showExamDialog(Map<String, dynamic> details, Map<String, dynamic>? my) {
    final subject = (details['subject_name'] ?? '').toString();
    final course = (details['course_name'] ?? '').toString();
    final examType = (details['exam_type'] ?? details['type'] ?? _type).toString();
    final maxScore = (details['max_score'] ?? details['maxScore'])?.toString();
    final studentScore = (details['student_score'] ?? my?['score'])?.toString();
    final dateStr = (details['exam_date'] ?? details['date'] ?? details['examDate'] ?? details['created_at'])?.toString();
    final examDate = (dateStr != null && dateStr.trim().isNotEmpty) ? DateTime.tryParse(dateStr) : null;
    final titleText = (details['title']?.toString().trim().isNotEmpty == true)
        ? details['title'].toString()
        : (subject.isNotEmpty ? 'امتحان ${examType == 'monthly' ? 'شهري' : 'يومي'} - $subject' : 'تفاصيل الامتحان');
    final desc = (details['description'] ?? '').toString().trim();
    final notes = (details['notes'] ?? '').toString().trim();

    showDialog(
      context: context,
      builder: (ctx) {
        final mq = ctx.mq;
        return Dialog(
          backgroundColor: mq.card,
          shape: const RoundedRectangleBorder(borderRadius: MqRadius.brXl),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(MqSpacing.lg),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [mq.accent, mq.accentDeep]),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(MqRadius.xl)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(MqSpacing.sm),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: MqRadius.brMd),
                        child: const Icon(Icons.quiz_outlined, color: Colors.white, size: 20),
                      ),
                      MqSpacing.gapSm,
                      Expanded(child: Text(titleText, style: ctx.text.titleSmall?.copyWith(color: Colors.white))),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(MqSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (subject.isNotEmpty) _row(ctx, Icons.menu_book_outlined, 'المادة', subject),
                        if (course.isNotEmpty) _row(ctx, Icons.class_outlined, 'الكورس', course),
                        if (maxScore != null) _row(ctx, Icons.grade_outlined, 'الدرجة القصوى', maxScore),
                        if (studentScore != null) _row(ctx, Icons.stars_rounded, 'درجتي', studentScore, tone: mq.success),
                        if (examDate != null) _row(ctx, Icons.event_outlined, 'التاريخ', _formatDate(examDate)),
                        if (examDate != null) _row(ctx, Icons.access_time_rounded, 'الحالة', _relativeFromNow(examDate)),
                        if (desc.isNotEmpty) ...[
                          const Divider(height: MqSpacing.xl),
                          Text('الوصف', style: ctx.text.labelMedium),
                          MqSpacing.gapXs,
                          MqSurface(tone: MqSurfaceTone.neutral, child: Text(desc, style: ctx.text.bodySmall?.copyWith(height: 1.4))),
                        ],
                        if (notes.isNotEmpty) ...[
                          MqSpacing.gapSm,
                          Text('الملاحظات', style: ctx.text.labelMedium),
                          MqSpacing.gapXs,
                          MqSurface(tone: MqSurfaceTone.orange, child: Text(notes, style: ctx.text.bodySmall?.copyWith(height: 1.4))),
                        ],
                        if (my != null && (my['status'] != null || my['feedback'] != null)) ...[
                          const Divider(height: MqSpacing.xl),
                          Text('تفاصيل درجتي', style: ctx.text.labelMedium),
                          MqSpacing.gapXs,
                          if (my['status'] != null) _row(ctx, Icons.check_circle_outline, 'الحالة', '${my['status']}', tone: mq.success),
                          if (my['feedback'] != null) _row(ctx, Icons.comment_outlined, 'ملاحظات المعلّم', '${my['feedback']}'),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(MqSpacing.md),
                  child: MqButton.secondary(label: 'إغلاق', onPressed: () => Navigator.pop(ctx)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, String value, {Color? tone}) {
    final mq = context.mq;
    final c = tone ?? mq.accent;
    return Padding(
      padding: const EdgeInsets.only(bottom: MqSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: MqRadius.brSm),
            child: Icon(icon, size: 14, color: c),
          ),
          MqSpacing.gapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.text.labelSmall),
                Text(value, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
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
        Center(
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(MqSpacing.lg),
              decoration: BoxDecoration(color: mq.accentSoft, shape: BoxShape.circle),
              child: Icon(Icons.quiz_outlined, size: 44, color: mq.accent),
            ),
            MqSpacing.gapMd,
            Text('لا توجد امتحانات', style: context.text.titleMedium),
            MqSpacing.gapXs,
            Text('ستظهر هنا امتحاناتك عند جدولتها.', textAlign: TextAlign.center, style: context.text.bodySmall),
          ]),
        ),
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
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.wifi_off_rounded, size: 44, color: mq.error),
            MqSpacing.gapMd,
            Text(_error ?? 'حدث خطأ', textAlign: TextAlign.center, style: context.text.bodyMedium),
            MqSpacing.gapMd,
            MqButton(label: 'إعادة المحاولة', icon: Icons.refresh_rounded, expand: false, onPressed: () => _fetch(reset: true)),
          ]),
        ),
      ],
    );
  }

  Widget _skeleton() {
    return Builder(builder: (context) {
      final mq = context.mq;
      return ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.md, MqSpacing.lg, MqSpacing.lg),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: MqSpacing.sm),
        itemBuilder: (_, _) => MqCard(
          padding: const EdgeInsets.all(MqSpacing.md),
          child: Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: mq.fill2, borderRadius: MqRadius.brMd)),
            MqSpacing.gapMd,
            Expanded(child: Container(height: 14, decoration: BoxDecoration(color: mq.fill2, borderRadius: MqRadius.brSm))),
          ]),
        ),
      );
    });
  }

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _relativeFromNow(DateTime when) {
    final diff = when.difference(DateTime.now());
    final isFuture = diff.inMilliseconds > 0;
    final abs = diff.abs();
    String human;
    if (abs.inDays >= 1) {
      human = '${abs.inDays} يوم';
    } else if (abs.inHours >= 1) {
      human = '${abs.inHours} ساعة';
    } else if (abs.inMinutes >= 1) {
      human = '${abs.inMinutes} دقيقة';
    } else {
      human = '${abs.inSeconds} ثانية';
    }
    return isFuture ? 'يبقى $human' : 'انتهى منذ $human';
  }
}
