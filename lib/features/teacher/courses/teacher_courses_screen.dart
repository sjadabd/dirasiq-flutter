import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/teacher_api_service.dart';
import '../shared/design/teacher_design.dart';
import '../shared/teacher_app_bar.dart';
import '../shared/teacher_drawer.dart';
import '../shared/teacher_helpers.dart' show fmtNum, fmtIQDShort;
import 'teacher_course_manage_screen.dart';
import 'widgets/teacher_course_form_dialog.dart';

/// Teacher → "الدورات" — matched to الدورات_Light/Dark.html.
///
/// Header + bottom nav follow the shared teacher chrome (per the request).
/// Real data only: course name / subject / grade / status (active vs ended by
/// `end_date`) / seats / price. Per-course attendance% & revenue from the mock
/// have no list endpoint, so the cards show the real seats/price/reservation
/// instead — no fabricated figures. Each card opens the course-management
/// screen via «إدارة» or the quick-action chips.
class TeacherCoursesScreen extends StatefulWidget {
  const TeacherCoursesScreen({super.key});
  @override
  State<TeacherCoursesScreen> createState() => _TeacherCoursesScreenState();
}

enum _Filter { all, active, ended, deleted }

class _TeacherCoursesScreenState extends State<TeacherCoursesScreen> {
  final _api = TeacherApiService();
  bool _loading = false;
  List<Map<String, dynamic>> _items = [];
  _Filter _filter = _Filter.all;
  String _search = '';
  final _searchCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await _api.fetchCourses(
          deleted: _filter == _Filter.deleted,
          search: _search.trim().isEmpty ? null : _search.trim(),
          page: 1,
          limit: 50);
      final list = res['data'];
      _items = (list is List)
          ? list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
          : [];
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّر جلب الدورات',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isEnded(Map c) {
    final end = DateTime.tryParse((c['end_date'] ?? '').toString());
    return end != null && end.isBefore(DateTime.now());
  }

  // Active / ended split is a client-side date filter on the non-deleted set.
  List<Map<String, dynamic>> get _visible {
    switch (_filter) {
      case _Filter.active:
        return _items.where((c) => !_isEnded(c)).toList();
      case _Filter.ended:
        return _items.where(_isEnded).toList();
      case _Filter.all:
      case _Filter.deleted:
        return _items;
    }
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('تأكيد الحذف'),
              content: const Text('سيتم حذف الدورة. يمكن استرجاعها لاحقاً.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('إلغاء')),
                FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('حذف')),
              ],
            ));
    if (ok != true) return;
    try {
      await _api.deleteCourse(c['id'].toString());
      Get.snackbar('تم', 'تم الحذف', snackPosition: SnackPosition.BOTTOM);
      await _fetch();
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّر الحذف', snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _restore(Map<String, dynamic> c) async {
    try {
      await _api.restoreCourse(c['id'].toString());
      Get.snackbar('تم', 'تم الاسترجاع', snackPosition: SnackPosition.BOTTOM);
      await _fetch();
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّر الاسترجاع',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _openManage(Map<String, dynamic> c, {int tab = 0}) async {
    await Get.to(() => TeacherCourseManageScreen(
          courseId: c['id'].toString(),
          course: c,
          initialTab: tab,
        ));
    _fetch();
  }

  Future<void> _openCreateDialog() async {
    final id = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const TeacherCourseFormDialog(),
    );
    if (id != null && mounted) {
      Get.snackbar('تم', 'تم إنشاء الدورة', snackPosition: SnackPosition.BOTTOM);
      setState(() => _filter = _Filter.all);
      await _fetch();
    }
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
          final visible = _visible;
          final activeCount = _items.where((c) => !_isEnded(c)).length;
          final endedCount = _items.where(_isEnded).length;

          return Scaffold(
            backgroundColor: mq.page,
            appBar: TeacherAppBar(
              title: 'الدورات',
              actions: [_RefreshAction(loading: _loading, onTap: _fetch)],
            ),
            drawer: const TeacherDrawer(),
            floatingActionButton: FloatingActionButton(
              onPressed: _loading ? null : _openCreateDialog,
              backgroundColor: mq.accent,
              foregroundColor: mq.onAccent,
              elevation: 3,
              tooltip: 'إضافة دورة',
              shape: const RoundedRectangleBorder(borderRadius: MqRadius.brLg),
              child: const Icon(Icons.add_rounded),
            ),
            body: RefreshIndicator(
              onRefresh: _fetch,
              color: mq.accent,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    MqSpacing.lg, MqSpacing.lg, MqSpacing.lg, 96),
                children: [
                  _hero(context, activeCount, endedCount),
                  const SizedBox(height: MqSpacing.lg),
                  _filterRow(context),
                  const SizedBox(height: MqSpacing.md),
                  _searchField(context),
                  const SizedBox(height: MqSpacing.lg),
                  if (_loading && _items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(MqSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (visible.isEmpty)
                    _EmptyState(
                        hasFilter: _filter != _Filter.all ||
                            _search.trim().isNotEmpty)
                  else
                    ...visible.map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: MqSpacing.md),
                          child: _CourseCard(
                            course: c,
                            ended: _isEnded(c),
                            onManage: ({int tab = 0}) =>
                                _openManage(c, tab: tab),
                            onDelete: () => _delete(c),
                            onRestore: () => _restore(c),
                          ),
                        )),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ---- hero (counts + summary strip) ----------------------------------------

  Widget _hero(BuildContext context, int activeCount, int endedCount) {
    final t = context.teacher;
    final totalSeats = _items.fold<int>(
        0, (s, c) => s + (num.tryParse('${c['seats_count'] ?? 0}')?.toInt() ?? 0));
    final totalValue = _items.fold<num>(
        0, (s, c) => s + (num.tryParse('${c['price'] ?? 0}') ?? 0));

    return Container(
      padding: const EdgeInsets.all(MqSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [t.heroA, t.heroB],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: MqRadius.brXl,
        boxShadow: t.shadowLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: context.mq.orange, shape: BoxShape.circle),
                child: const Icon(Icons.school_outlined,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: MqSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الدورات',
                        style: context.text.titleMedium
                            ?.copyWith(color: t.heroInk)),
                    const SizedBox(height: 2),
                    Text('$activeCount نشطة · $endedCount منتهية',
                        style: context.text.labelSmall
                            ?.copyWith(color: t.heroInk2)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: MqSpacing.lg),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _heroStat(context, '${_items.length}', 'إجمالي الدورات'),
                const SizedBox(width: MqSpacing.sm),
                _heroStat(context, fmtNum(totalSeats), 'إجمالي المقاعد'),
                const SizedBox(width: MqSpacing.sm),
                _heroStat(context, fmtIQDShort(totalValue), 'قيمة الدورات'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStat(BuildContext context, String value, String label) {
    final t = context.teacher;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: MqSpacing.sm, vertical: MqSpacing.sm),
        decoration: BoxDecoration(
          color: t.heroTile,
          borderRadius: MqRadius.brMd,
          border: Border.all(color: t.heroLine),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: MqTypography.mono(
                      color: t.heroInk, size: 17, weight: FontWeight.w700)),
            ),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(color: t.heroInk2)),
          ],
        ),
      ),
    );
  }

  // ---- filters + search -----------------------------------------------------

  Widget _filterRow(BuildContext context) {
    final filters = <(_Filter, String)>[
      (_Filter.all, 'الكل'),
      (_Filter.active, 'نشطة'),
      (_Filter.ended, 'منتهية'),
      (_Filter.deleted, 'محذوفة'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (value, label) in filters) ...[
            MqChip(
              label: label,
              selected: _filter == value,
              onTap: () {
                setState(() => _filter = value);
                _fetch();
              },
            ),
            const SizedBox(width: MqSpacing.sm),
          ],
        ],
      ),
    );
  }

  Widget _searchField(BuildContext context) {
    return TextField(
      controller: _searchCtl,
      onChanged: (v) => setState(() => _search = v),
      onSubmitted: (_) => _fetch(),
      decoration: InputDecoration(
        hintText: 'بحث في اسم الدورة...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _search.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchCtl.clear();
                  setState(() => _search = '');
                  _fetch();
                },
                icon: const Icon(Icons.clear_rounded),
              ),
        isDense: true,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _RefreshAction extends StatelessWidget {
  const _RefreshAction({required this.loading, required this.onTap});
  final bool loading;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MqSpacing.xs),
      child: Material(
        color: mq.fill,
        shape: RoundedRectangleBorder(
          borderRadius: MqRadius.brMd,
          side: BorderSide(color: mq.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: loading ? null : () => onTap(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: loading
                ? Padding(
                    padding: const EdgeInsets.all(11),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: mq.ink3),
                  )
                : Icon(Icons.refresh_rounded,
                    size: MqSize.iconSm, color: mq.ink2),
          ),
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.ended,
    required this.onManage,
    required this.onDelete,
    required this.onRestore,
  });
  final Map<String, dynamic> course;
  final bool ended;
  final void Function({int tab}) onManage;
  final VoidCallback onDelete, onRestore;

  static const _chips = <(String, int, IconData)>[
    ('الطلاب', 1, Icons.group_outlined),
    ('الحضور', 2, Icons.fact_check_outlined),
    ('الواجبات', 3, Icons.assignment_outlined),
    ('الاختبارات', 4, Icons.quiz_outlined),
    ('الدرجات', 5, Icons.grade_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final t = context.teacher;
    final c = course;
    final isDeleted = c['deleted_at'] != null || c['is_deleted'] == true;
    final subject = (c['subject_name'] ?? '').toString();
    final grade = (c['grade_name'] ?? '').toString();
    final meta = [subject, grade].where((s) => s.isNotEmpty).join(' · ');
    final hasReservation = c['has_reservation'] == true;

    final (statusLabel, statusTone) = isDeleted
        ? ('محذوفة', TeacherTone.danger)
        : ended
            ? ('منتهية', TeacherTone.neutral)
            : ('نشطة', TeacherTone.success);

    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      onTap: isDeleted ? null : () => onManage(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // title + status + delete/restore
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: t.infoSoft,
                  borderRadius: MqRadius.brMd,
                  border: Border.all(color: t.infoLine),
                ),
                child: Icon(Icons.book_outlined, color: t.info, size: 22),
              ),
              const SizedBox(width: MqSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((c['course_name'] ?? '—').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    if (meta.isNotEmpty)
                      Text(meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelSmall
                              ?.copyWith(color: mq.ink3)),
                  ],
                ),
              ),
              const SizedBox(width: MqSpacing.sm),
              TeacherStatusPill(label: statusLabel, tone: statusTone),
            ],
          ),
          const SizedBox(height: MqSpacing.md),
          // meta cells (real: seats / price / reservation)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: MqSpacing.md, vertical: MqSpacing.sm),
            decoration:
                BoxDecoration(color: mq.fill, borderRadius: MqRadius.brMd),
            child: Row(
              children: [
                _Meta(
                    icon: Icons.event_seat_outlined,
                    text: '${c['seats_count'] ?? 0} مقعد',
                    tone: TeacherTone.info),
                _Meta(
                    icon: Icons.payments_outlined,
                    text: '${fmtNum(c['price'])} د.ع',
                    tone: TeacherTone.success),
                if (hasReservation)
                  _Meta(
                      icon: Icons.savings_outlined,
                      text: 'عربون ${fmtNum(c['reservation_amount'])}',
                      tone: TeacherTone.warning),
              ],
            ),
          ),
          const SizedBox(height: MqSpacing.md),
          if (isDeleted)
            MqButton.secondary(
              label: 'استرجاع الدورة',
              icon: Icons.restore_rounded,
              size: MqButtonSize.small,
              onPressed: onRestore,
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: MqButton(
                    label: 'إدارة الدورة',
                    icon: Icons.tune_rounded,
                    size: MqButtonSize.small,
                    onPressed: () => onManage(),
                  ),
                ),
                const SizedBox(width: MqSpacing.sm),
                _IconBtn(
                    icon: Icons.delete_outline_rounded,
                    color: mq.error,
                    onTap: onDelete),
              ],
            ),
            const SizedBox(height: MqSpacing.sm),
            // quick-action chips → open management at the matching tab
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (label, tab, icon) in _chips) ...[
                    _QuickChip(
                        label: label,
                        icon: icon,
                        onTap: () => onManage(tab: tab)),
                    const SizedBox(width: MqSpacing.xs),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, required this.tone});
  final IconData icon;
  final String text;
  final TeacherTone tone;

  @override
  Widget build(BuildContext context) {
    final t = context.teacher;
    final color = switch (tone) {
      TeacherTone.success => t.success,
      TeacherTone.info => t.info,
      TeacherTone.warning => t.warning,
      TeacherTone.danger => t.danger,
      TeacherTone.neutral => context.mq.ink2,
    };
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: MqSpacing.xs),
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall
                    ?.copyWith(color: color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip(
      {required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Material(
      color: mq.fill,
      shape: RoundedRectangleBorder(
        borderRadius: MqRadius.brPill,
        side: BorderSide(color: mq.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: MqSpacing.md, vertical: MqSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: mq.ink2),
              const SizedBox(width: MqSpacing.xs),
              Text(label,
                  style: context.text.labelSmall?.copyWith(color: mq.ink2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Material(
      color: mq.fill,
      shape: RoundedRectangleBorder(
        borderRadius: MqRadius.brSm,
        side: BorderSide(color: mq.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: MqSize.buttonHeightSm,
          height: MqSize.buttonHeightSm,
          child: Icon(icon, size: MqSize.iconSm, color: color),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilter});
  final bool hasFilter;
  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.xl),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: mq.fill2, shape: BoxShape.circle),
            child: Icon(Icons.school_outlined, size: 34, color: mq.ink3),
          ),
          const SizedBox(height: MqSpacing.md),
          Text(
            hasFilter ? 'لا توجد دورات بهذه الفلاتر' : 'لا توجد دورات بعد',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: mq.ink2),
          ),
          const SizedBox(height: MqSpacing.xs),
          Text(
            'أنشئ دورتك الأولى من زر «إضافة دورة»',
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(color: mq.ink3),
          ),
        ],
      ),
    );
  }
}
