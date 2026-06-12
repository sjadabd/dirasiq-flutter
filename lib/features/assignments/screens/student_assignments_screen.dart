// Student → Assignments list (MulhimIQ design-system pass).
//
// Backed by the existing endpoint ApiService.fetchStudentAssignments(page,
// limit) — no backend change. The list endpoint returns `SELECT a.*` only, so
// it carries NO submission status / grade / course-name / teacher-name (those
// live in the submission, surfaced on the details screen). Per the project's
// "hide unsupported" rule:
//   • status filters (solved/unsolved/late/graded) are NOT rendered — the list
//     has no submission status.
//   • status badge here is DUE-derived (overdue / due-soon) from `due_date`.
//   • grade / course / teacher are hidden (not provided by the list).
//
// Tapping a card opens AssignmentDetailsScreen, which owns the full
// open → submit → view-result flow (unchanged).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/features/assignments/screens/assignment_details_screen.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';

class StudentAssignmentsScreen extends StatefulWidget {
  const StudentAssignmentsScreen({super.key});

  @override
  State<StudentAssignmentsScreen> createState() => _StudentAssignmentsScreenState();
}

class _StudentAssignmentsScreenState extends State<StudentAssignmentsScreen> {
  final _api = ApiService();
  final _scroll = ScrollController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetch();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _fetch({bool refresh = false}) async {
    try {
      if (refresh) {
        setState(() {
          _loading = true;
          _error = null;
          _page = 1;
          _items = [];
          _hasMore = true;
        });
      }
      if (!_hasMore && !refresh) return;

      final res = await _api.fetchStudentAssignments(page: _page, limit: 10);
      final list = List<Map<String, dynamic>>.from((res['items'] ?? res['data'] ?? []) as List);
      final pagination = Map<String, dynamic>.from(res['pagination'] ?? {});
      final total = (pagination['total'] ?? list.length) as int;

      setState(() {
        _items.addAll(list);
        _loading = false;
        _hasMore = _items.length < total;
        if (_hasMore) _page += 1;
      });
    } catch (e) {
      setState(() {
        _error = 'تعذّر تحميل الواجبات';
        _loading = false;
      });
    }
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      if (!_loading && _hasMore) _fetch();
    }
  }

  DateTime? _due(Map<String, dynamic> a) {
    final raw = (a['due_at'] ?? a['dueAt'] ?? a['due_date'])?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  void _open(Map<String, dynamic> a) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssignmentDetailsScreen(assignmentId: (a['id'] ?? a['_id']).toString()),
      ),
    );
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
            appBar: AppBar(title: const Text('الواجبات')),
            body: _body(context),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading && _items.isEmpty) return _skeleton();
    if (_error != null && _items.isEmpty) return _errorView(context);
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _fetch(refresh: true),
        child: _empty(context),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetch(refresh: true),
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.md, MqSpacing.lg, MqSpacing.xxxl),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: MqSpacing.sm),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return const Padding(
              padding: EdgeInsets.all(MqSpacing.md),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return _card(context, _items[index]);
        },
      ),
    );
  }

  Widget _card(BuildContext context, Map<String, dynamic> a) {
    final mq = context.mq;
    final title = (a['title'] ?? a['name'] ?? 'واجب').toString();
    final desc = (a['description'] ?? '').toString().trim();
    final due = _due(a);

    final ({String label, MqBadgeTone tone})? dueBadge = due == null
        ? null
        : due.isBefore(DateTime.now())
            ? (label: 'انتهى الموعد', tone: MqBadgeTone.error)
            : due.difference(DateTime.now()).inHours <= 48
                ? (label: 'اقترب الموعد', tone: MqBadgeTone.orange)
                : null;

    return MqCard(
      onTap: () => _open(a),
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
                child: Icon(Icons.assignment_outlined, color: mq.accent, size: MqSize.iconMd),
              ),
              MqSpacing.gapMd,
              Expanded(
                child: Text(title, style: context.text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              if (dueBadge != null) ...[MqSpacing.gapXs, MqBadge(label: dueBadge.label, tone: dueBadge.tone)],
            ],
          ),
          if (desc.isNotEmpty) ...[
            MqSpacing.gapSm,
            Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall?.copyWith(height: 1.45)),
          ],
          if (due != null) ...[
            MqSpacing.gapSm,
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 13, color: mq.ink3),
                MqSpacing.gapXxs,
                Text('تسليم حتى: ${DateFormat('dd/MM • HH:mm').format(due)}', style: context.text.labelSmall),
              ],
            ),
          ],
          MqSpacing.gapMd,
          MqButton(label: 'عرض الواجب', size: MqButtonSize.small, onPressed: () => _open(a)),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final mq = context.mq;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MqSpacing.lg),
      children: [
        const SizedBox(height: MqSpacing.xxl),
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(MqSpacing.lg),
                decoration: BoxDecoration(color: mq.accentSoft, shape: BoxShape.circle),
                child: Icon(Icons.assignment_outlined, size: 44, color: mq.accent),
              ),
              MqSpacing.gapMd,
              Text('لا توجد واجبات حالياً', style: context.text.titleMedium),
              MqSpacing.gapXs,
              Text('ستظهر هنا واجباتك من أساتذتك عند إسنادها.',
                  textAlign: TextAlign.center, style: context.text.bodySmall),
            ],
          ),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 44, color: mq.error),
              MqSpacing.gapMd,
              Text(_error ?? 'حدث خطأ', textAlign: TextAlign.center, style: context.text.bodyMedium),
              MqSpacing.gapMd,
              MqButton(label: 'إعادة المحاولة', icon: Icons.refresh_rounded, expand: false,
                  onPressed: () => _fetch(refresh: true)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _skeleton() {
    return Builder(builder: (context) {
      final mq = context.mq;
      Widget bar(double w, double h) =>
          Container(width: w, height: h, decoration: BoxDecoration(color: mq.fill2, borderRadius: MqRadius.brSm));
      return ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.md, MqSpacing.lg, MqSpacing.lg),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: MqSpacing.sm),
        itemBuilder: (_, _) => MqCard(
          padding: const EdgeInsets.all(MqSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: mq.fill2, borderRadius: MqRadius.brMd)),
                MqSpacing.gapMd,
                Expanded(child: bar(180, 14)),
              ]),
              MqSpacing.gapMd,
              bar(double.infinity, 36),
            ],
          ),
        ),
      );
    });
  }
}
