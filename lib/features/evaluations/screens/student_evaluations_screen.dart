// Student → Teacher evaluations (MulhimIQ design-system pass).
//
// Opened from Course Hub → الأكاديمي → تقييمات الأستاذ. These are the teacher's
// assessments OF the student (scientific / behavioral / attendance / homework /
// participation / instruction levels). The student does NOT submit evaluations
// here, so there is no submit/update flow — the existing action is "view
// details" (bottom sheet). Backed by existing endpoints (no backend change):
//   • fetchStudentEvaluations(from, to, page, limit) → list
//   • fetchStudentEvaluationById(id)                  → deep-link open
//
// The list items carry rating levels + guidance/notes/date — NO teacher name or
// course name, so those are hidden (per "hide missing fields").

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';

class StudentEvaluationsScreen extends StatefulWidget {
  final String? initialEvaluationId;
  const StudentEvaluationsScreen({super.key, this.initialEvaluationId});

  @override
  State<StudentEvaluationsScreen> createState() => _StudentEvaluationsScreenState();
}

class _StudentEvaluationsScreenState extends State<StudentEvaluationsScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  int _page = 1;
  final int _limit = 10;
  bool _hasMore = true;

  DateTime? _from;
  DateTime? _to;

  static const Map<String, String> _ratingAr = {
    'excellent': 'ممتاز',
    'very_good': 'جيد جدًا',
    'good': 'جيد',
    'fair': 'مقبول',
    'weak': 'ضعيف',
  };

  String _toAr(String? v) => (v == null || v.isEmpty) ? '—' : (_ratingAr[v] ?? v);

  MqBadgeTone _tone(String? v) {
    switch (v) {
      case 'excellent':
      case 'very_good':
        return MqBadgeTone.success;
      case 'good':
        return MqBadgeTone.accent;
      case 'fair':
        return MqBadgeTone.orange;
      case 'weak':
        return MqBadgeTone.error;
      default:
        return MqBadgeTone.neutral;
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      return DateFormat('yyyy-MM-dd').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }

  String _fmtYMD(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  @override
  void initState() {
    super.initState();
    _fetch(refresh: true).then((_) {
      final id = widget.initialEvaluationId;
      if (id != null && id.isNotEmpty) {
        final found = _items.firstWhere(
          (e) => (e['id'] ?? e['_id'] ?? '').toString() == id,
          orElse: () => {},
        );
        if (found.isNotEmpty) {
          _openDetails(found);
        } else {
          _openDetailsById(id);
        }
      }
    });
  }

  Future<void> _fetch({bool refresh = false}) async {
    try {
      if (refresh) {
        setState(() {
          _loading = true;
          _error = null;
          _items = [];
          _page = 1;
          _hasMore = true;
        });
      }
      if (!_hasMore && !refresh) return;

      final res = await _api.fetchStudentEvaluations(
        from: _from != null ? _fmtYMD(_from!) : null,
        to: _to != null ? _fmtYMD(_to!) : null,
        page: _page,
        limit: _limit,
      );
      final dataList = List<Map<String, dynamic>>.from(res['data'] ?? res['items'] ?? []);
      final pagination = (res['pagination'] is Map) ? Map<String, dynamic>.from(res['pagination']) : <String, dynamic>{};
      final total = pagination['total'] is int ? pagination['total'] as int : null;

      setState(() {
        _items.addAll(dataList);
        _loading = false;
        _hasMore = total != null ? _items.length < total : dataList.length == _limit;
        if (_hasMore) _page += 1;
      });
    } catch (e) {
      setState(() {
        _error = 'تعذّر تحميل التقييمات';
        _loading = false;
      });
    }
  }

  Future<void> _openDetailsById(String id) async {
    try {
      final data = await _api.fetchStudentEvaluationById(id);
      if (!mounted) return;
      _openDetails(data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  Future<void> _pickFrom() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context, firstDate: DateTime(now.year - 5), lastDate: DateTime(now.year + 5),
      initialDate: _from ?? now, locale: const Locale('ar'),
    );
    if (d != null) {
      setState(() => _from = d);
      _fetch(refresh: true);
    }
  }

  Future<void> _pickTo() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context, firstDate: DateTime(now.year - 5), lastDate: DateTime(now.year + 5),
      initialDate: _to ?? now, locale: const Locale('ar'),
    );
    if (d != null) {
      setState(() => _to = d);
      _fetch(refresh: true);
    }
  }

  void _clearFilters() {
    setState(() {
      _from = null;
      _to = null;
    });
    _fetch(refresh: true);
  }

  // ── build ─────────────────────────────────────────────────────────────────

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
            appBar: AppBar(title: const Text('تقييمات الأستاذ')),
            body: Column(
              children: [
                _filterBar(context),
                Expanded(
                  child: RefreshIndicator(onRefresh: () => _fetch(refresh: true), child: _bodyView(context)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterBar(BuildContext context) {
    final mq = context.mq;
    return Container(
      decoration: BoxDecoration(color: mq.page, border: Border(bottom: BorderSide(color: mq.line))),
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.sm, MqSpacing.lg, MqSpacing.sm),
      child: Row(
        children: [
          Expanded(child: MqButton.secondary(
            label: _from != null ? _fmtYMD(_from!) : 'من تاريخ',
            icon: Icons.date_range_outlined, size: MqButtonSize.small, onPressed: _pickFrom)),
          MqSpacing.gapSm,
          Expanded(child: MqButton.secondary(
            label: _to != null ? _fmtYMD(_to!) : 'إلى تاريخ',
            icon: Icons.date_range_outlined, size: MqButtonSize.small, onPressed: _pickTo)),
          if (_from != null || _to != null) ...[
            MqSpacing.gapSm,
            IconButton(
              tooltip: 'مسح',
              icon: Icon(Icons.clear_rounded, color: mq.ink2),
              onPressed: _clearFilters,
            ),
          ],
        ],
      ),
    );
  }

  Widget _bodyView(BuildContext context) {
    if (_loading && _items.isEmpty) return _skeleton(context);
    if (_error != null && _items.isEmpty) return _errorView(context);
    if (_items.isEmpty) return _empty(context);

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.md, MqSpacing.lg, MqSpacing.xxxl),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: MqSpacing.sm),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          _fetch();
          return const Padding(
            padding: EdgeInsets.all(MqSpacing.md),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return _card(context, _items[index]);
      },
    );
  }

  Widget _card(BuildContext context, Map<String, dynamic> ev) {
    final mq = context.mq;
    final date = _fmtDate(ev['eval_date']?.toString() ?? ev['date']?.toString());
    final sci = ev['scientific_level']?.toString();
    final notes = (ev['notes'] ?? '').toString().trim();

    final dims = <(String, String?)>[
      ('علمي', ev['scientific_level']?.toString()),
      ('سلوكي', ev['behavioral_level']?.toString()),
      ('حضوري', ev['attendance_level']?.toString()),
      ('واجب', ev['homework_preparation']?.toString()),
      ('مشاركة', ev['participation_level']?.toString()),
      ('تعليمات', ev['instruction_following']?.toString()),
    ].where((d) => d.$2 != null && d.$2!.isNotEmpty).toList();

    return MqCard(
      onTap: () => _openDetails(ev),
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: mq.accentSoft, borderRadius: MqRadius.brMd),
                child: Icon(Icons.fact_check_outlined, size: MqSize.iconSm, color: mq.accent),
              ),
              MqSpacing.gapSm,
              Expanded(child: Text(date.isNotEmpty ? 'تقييم بتاريخ $date' : 'تقييم', style: context.text.titleSmall)),
              if (sci != null && sci.isNotEmpty) ...[
                MqSpacing.gapXs,
                MqBadge(label: _toAr(sci), tone: _tone(sci), solid: true),
              ],
            ],
          ),
          if (dims.isNotEmpty) ...[
            MqSpacing.gapSm,
            Wrap(
              spacing: MqSpacing.xs,
              runSpacing: MqSpacing.xxs,
              children: [for (final d in dims) MqBadge(label: '${d.$1}: ${_toAr(d.$2)}', tone: _tone(d.$2))],
            ),
          ],
          if (notes.isNotEmpty) ...[
            MqSpacing.gapSm,
            Text(notes, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
          ],
          MqSpacing.gapMd,
          MqButton(label: 'عرض التفاصيل', size: MqButtonSize.small, onPressed: () => _openDetails(ev)),
        ],
      ),
    );
  }

  // ── details bottom sheet (existing flow, restyled) ─────────────────────────

  void _openDetails(Map<String, dynamic> ev) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dsTheme = isDark ? MqTheme.dark() : MqTheme.light();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Theme(
        data: dsTheme,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Builder(builder: (context) {
            final mq = context.mq;
            final dims = <(IconData, String, String?)>[
              (Icons.school_outlined, 'المستوى العلمي', ev['scientific_level']?.toString()),
              (Icons.psychology_outlined, 'المستوى السلوكي', ev['behavioral_level']?.toString()),
              (Icons.access_time_outlined, 'الانضباط الحضوري', ev['attendance_level']?.toString()),
              (Icons.book_outlined, 'التحضير للواجبات', ev['homework_preparation']?.toString()),
              (Icons.group_outlined, 'المشاركة', ev['participation_level']?.toString()),
              (Icons.rule_outlined, 'اتباع التعليمات', ev['instruction_following']?.toString()),
            ];
            final guidance = (ev['guidance'] ?? '').toString().trim();
            final notes = (ev['notes'] ?? '').toString().trim();
            final date = _fmtDate(ev['eval_date']?.toString() ?? ev['date']?.toString());

            return Container(
              decoration: BoxDecoration(
                color: mq.card,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(MqRadius.xl)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + MqSpacing.lg,
                left: MqSpacing.lg, right: MqSpacing.lg, top: MqSpacing.lg,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: mq.accentSoft, borderRadius: MqRadius.brMd),
                          child: Icon(Icons.fact_check_outlined, color: mq.accent, size: MqSize.iconSm),
                        ),
                        MqSpacing.gapSm,
                        Expanded(child: Text('تفاصيل التقييم', style: context.text.titleMedium)),
                        IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: mq.ink2)),
                      ],
                    ),
                    if (date.isNotEmpty) ...[
                      MqSpacing.gapXs,
                      Row(children: [
                        Icon(Icons.event_outlined, size: 14, color: mq.ink3),
                        MqSpacing.gapXxs,
                        Text(date, style: context.text.bodySmall),
                      ]),
                    ],
                    MqSpacing.gapMd,
                    MqSurface(
                      tone: MqSurfaceTone.neutral,
                      child: Column(
                        children: [
                          for (var i = 0; i < dims.length; i++) ...[
                            if (i > 0) MqSpacing.gapSm,
                            Row(children: [
                              Icon(dims[i].$1, size: 15, color: mq.ink3),
                              MqSpacing.gapSm,
                              Expanded(child: Text(dims[i].$2, style: context.text.bodyMedium)),
                              MqBadge(label: _toAr(dims[i].$3), tone: _tone(dims[i].$3)),
                            ]),
                          ],
                        ],
                      ),
                    ),
                    if (guidance.isNotEmpty) ...[
                      MqSpacing.gapMd,
                      Text('التوجيه', style: context.text.labelMedium),
                      MqSpacing.gapXs,
                      MqSurface(tone: MqSurfaceTone.accent, child: Text(guidance, style: context.text.bodySmall?.copyWith(height: 1.4))),
                    ],
                    if (notes.isNotEmpty) ...[
                      MqSpacing.gapMd,
                      Text('الملاحظات', style: context.text.labelMedium),
                      MqSpacing.gapXs,
                      MqSurface(tone: MqSurfaceTone.orange, child: Text(notes, style: context.text.bodySmall?.copyWith(height: 1.4))),
                    ],
                    MqSpacing.gapXl,
                  ],
                ),
              ),
            );
          }),
        ),
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
            child: Icon(Icons.fact_check_outlined, size: 44, color: mq.accent),
          ),
          MqSpacing.gapMd,
          Text('لا توجد تقييمات', style: context.text.titleMedium),
          MqSpacing.gapXs,
          Text('ستظهر هنا تقييمات أستاذك لأدائك.', textAlign: TextAlign.center, style: context.text.bodySmall),
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
          MqButton(label: 'إعادة المحاولة', icon: Icons.refresh_rounded, expand: false, onPressed: () => _fetch(refresh: true)),
        ])),
      ],
    );
  }

  Widget _skeleton(BuildContext context) {
    final mq = context.mq;
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.md, MqSpacing.lg, MqSpacing.lg),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: MqSpacing.sm),
      itemBuilder: (_, _) => MqCard(
        padding: const EdgeInsets.all(MqSpacing.md),
        child: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: mq.fill2, borderRadius: MqRadius.brMd)),
          MqSpacing.gapSm,
          Expanded(child: Container(height: 14, decoration: BoxDecoration(color: mq.fill2, borderRadius: MqRadius.brSm))),
        ]),
      ),
    );
  }
}
