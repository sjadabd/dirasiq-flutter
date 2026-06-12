import 'package:flutter/material.dart';

import '../../../core/services/teacher_api_service.dart';
import '../shared/design/teacher_design.dart';
import '../shared/teacher_app_bar.dart';
import '../shared/teacher_drawer.dart';

/// Teacher → "المواد الدراسية" — full CRUD (Teacher Design System pass).
///
/// Presentation only — `fetchSubjects`, `createSubject`, `updateSubject`,
/// `deleteSubject`, `restoreSubject`, the status filter, and the search are
/// UNCHANGED. Restyled to the teacher design system; the add/edit dialog is now
/// an animated bottom sheet.
class TeacherSubjectsScreen extends StatefulWidget {
  const TeacherSubjectsScreen({super.key});
  @override
  State<TeacherSubjectsScreen> createState() => _TeacherSubjectsScreenState();
}

class _TeacherSubjectsScreenState extends State<TeacherSubjectsScreen> {
  final _api = TeacherApiService();
  bool _loading = false;
  List<Map<String, dynamic>> _items = [];
  bool? _deletedFilter = false;
  String _search = '';
  final _searchCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  /// Native messenger toast. Replaces `Get.snackbar` here: GetX's snackbar
  /// inserts its own overlay route, which collides with the bottom-sheet pop
  /// teardown and trips the framework `_dependents.isEmpty` assertion (the red
  /// error screen). `ScaffoldMessenger` is route-lifecycle safe.
  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await _api.fetchSubjects(
          isDeleted: _deletedFilter,
          search: _search.trim().isEmpty ? null : _search.trim(),
          page: 1,
          limit: 100);
      final list = res['data'];
      _items = (list is List)
          ? list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
          : [];
    } catch (_) {
      _toast('تعذّر جلب المواد');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showSubjectSheet({Map<String, dynamic>? existing}) async {
    final nameCtl = TextEditingController(text: (existing?['name'] ?? '').toString());
    final descCtl =
        TextEditingController(text: (existing?['description'] ?? '').toString());
    bool saving = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Theme(
        data: isDark ? MqTheme.dark() : MqTheme.light(),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(builder: (sheetCtx, setLocal) {
            final mq = sheetCtx.mq;

            Future<void> save() async {
              if (nameCtl.text.trim().isEmpty) {
                _toast('اسم المادة مطلوب');
                return;
              }
              setLocal(() => saving = true);
              try {
                final payload = {'name': nameCtl.text.trim()};
                if (descCtl.text.trim().isNotEmpty) {
                  payload['description'] = descCtl.text.trim();
                }
                if (existing == null) {
                  await _api.createSubject(payload);
                } else {
                  await _api.updateSubject(existing['id'].toString(), payload);
                }
                // Dismiss the keyboard BEFORE popping. A focused TextField +
                // the keyboard view-inset collapsing during the route teardown
                // is what trips `_dependents.isEmpty` (the red screen).
                FocusManager.instance.primaryFocus?.unfocus();
                if (sheetCtx.mounted) Navigator.pop(sheetCtx, true);
              } catch (e) {
                setLocal(() => saving = false);
                _toast(_apiMessage(e) ?? 'تعذّر الحفظ');
              }
            }

            return Padding(
              padding:
                  EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: mq.card,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(MqRadius.xl)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
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
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                  color: mq.accentSoft,
                                  borderRadius: MqRadius.brSm),
                              child: Icon(
                                  existing == null
                                      ? Icons.add_rounded
                                      : Icons.edit_outlined,
                                  size: MqSize.iconSm,
                                  color: mq.accent),
                            ),
                            const SizedBox(width: MqSpacing.sm),
                            Expanded(
                              child: Text(
                                  existing == null ? 'إضافة مادة' : 'تعديل المادة',
                                  style: sheetCtx.text.titleMedium),
                            ),
                            InkWell(
                              onTap: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                Navigator.pop(sheetCtx, false);
                              },
                              customBorder: const CircleBorder(),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(Icons.close_rounded, color: mq.ink3),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: MqSpacing.lg),
                        TextField(
                          controller: nameCtl,
                          decoration: const InputDecoration(
                            labelText: 'اسم المادة *',
                            prefixIcon: Icon(Icons.menu_book_outlined),
                          ),
                        ),
                        const SizedBox(height: MqSpacing.md),
                        TextField(
                          controller: descCtl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'الوصف',
                            hintText: 'وصف اختياري للمادة...',
                          ),
                        ),
                        const SizedBox(height: MqSpacing.xl),
                        MqButton(
                          label: saving ? 'جارٍ الحفظ…' : 'حفظ',
                          icon: saving ? null : Icons.check_rounded,
                          loading: saving,
                          onPressed: saving ? null : save,
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

    // Dispose AFTER the sheet's slide-out animation finishes. The TextFields
    // are still mounted and rebuilding during the exit transition; disposing
    // their controllers synchronously here makes a still-animating TextField
    // call addListener() on a disposed ChangeNotifier — which surfaces as the
    // red `_dependents.isEmpty` / "used after dispose" screen.
    Future.delayed(const Duration(milliseconds: 500), () {
      nameCtl.dispose();
      descCtl.dispose();
    });

    if (ok == true) {
      await _fetch();
      _toast(existing == null ? 'تمت الإضافة' : 'تم التعديل');
    }
  }

  Future<void> _delete(Map<String, dynamic> s) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('تأكيد الحذف'),
              content: const Text('سيتم حذف المادة. يمكن استرجاعها.'),
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
      await _api.deleteSubject(s['id'].toString());
      await _fetch();
      _toast('تم الحذف');
    } catch (e) {
      _toast(_apiMessage(e) ?? 'تعذّر الحذف');
    }
  }

  Future<void> _restore(Map<String, dynamic> s) async {
    try {
      await _api.restoreSubject(s['id'].toString());
      await _fetch();
      _toast('تم الاسترجاع');
    } catch (e) {
      _toast(_apiMessage(e) ?? 'تعذّر الاسترجاع');
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
          return Scaffold(
            backgroundColor: mq.page,
            appBar: TeacherAppBar(
              title: 'المواد الدراسية',
              actions: [_RefreshAction(loading: _loading, onTap: _fetch)],
            ),
            drawer: const TeacherDrawer(),
            floatingActionButton: FloatingActionButton(
              onPressed: () => _showSubjectSheet(),
              backgroundColor: mq.accent,
              foregroundColor: mq.onAccent,
              elevation: 3,
              tooltip: 'إضافة مادة',
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
                  _hero(context),
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
                  else if (_items.isEmpty)
                    _EmptyState(
                        hasFilter: _deletedFilter != false ||
                            _search.trim().isNotEmpty)
                  else
                    ..._items.map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: MqSpacing.md),
                          child: _SubjectCard(
                            subject: s,
                            onEdit: () => _showSubjectSheet(existing: s),
                            onDelete: () => _delete(s),
                            onRestore: () => _restore(s),
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

  Widget _hero(BuildContext context) {
    final t = context.teacher;
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
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration:
                BoxDecoration(color: context.mq.orange, shape: BoxShape.circle),
            child: const Icon(Icons.menu_book_outlined,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: MqSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المواد الدراسية',
                    style: context.text.titleMedium?.copyWith(color: t.heroInk)),
                const SizedBox(height: 2),
                Text('${_items.length} مادة',
                    style:
                        context.text.labelSmall?.copyWith(color: t.heroInk2)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterRow(BuildContext context) {
    final filters = <(bool?, String)>[
      (false, 'نشطة'),
      (true, 'محذوفة'),
      (null, 'الكل'),
    ];
    return Row(
      children: [
        for (final (value, labelTxt) in filters) ...[
          MqChip(
            label: labelTxt,
            selected: _deletedFilter == value,
            onTap: () {
              setState(() => _deletedFilter = value);
              _fetch();
            },
          ),
          const SizedBox(width: MqSpacing.sm),
        ],
      ],
    );
  }

  Widget _searchField(BuildContext context) {
    return TextField(
      controller: _searchCtl,
      onChanged: (v) => setState(() => _search = v),
      onSubmitted: (_) => _fetch(),
      decoration: InputDecoration(
        hintText: 'بحث في اسم المادة...',
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

/// Pulls the server's `message` out of a thrown API error (DioException or
/// any object exposing `.response.data['message']`) without importing dio.
/// Returns null when no useful message is present, so callers fall back to a
/// generic string.
String? _apiMessage(Object e) {
  try {
    final data = (e as dynamic).response?.data;
    if (data is Map && data['message'] is String) {
      final m = (data['message'] as String).trim();
      if (m.isNotEmpty) return m;
    }
  } catch (_) {}
  return null;
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

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.subject,
    required this.onEdit,
    required this.onDelete,
    required this.onRestore,
  });
  final Map<String, dynamic> subject;
  final VoidCallback onEdit, onDelete, onRestore;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final t = context.teacher;
    final isDeleted =
        subject['deleted_at'] != null || subject['is_deleted'] == true;
    final desc = (subject['description'] ?? '').toString();
    final base = isDeleted ? t.danger : t.info;
    final soft = isDeleted ? t.dangerSoft : t.infoSoft;
    final line = isDeleted ? t.dangerLine : t.infoLine;

    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: soft,
              borderRadius: MqRadius.brMd,
              border: Border.all(color: line),
            ),
            child: Icon(Icons.menu_book_outlined, color: base, size: 20),
          ),
          const SizedBox(width: MqSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text((subject['name'] ?? '—').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    if (isDeleted) ...[
                      const SizedBox(width: MqSpacing.sm),
                      const TeacherStatusPill(
                          label: 'محذوفة', tone: TeacherTone.danger),
                    ],
                  ],
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(color: mq.ink2)),
                ],
              ],
            ),
          ),
          const SizedBox(width: MqSpacing.sm),
          if (isDeleted)
            _IconBtn(
                icon: Icons.restore_rounded, color: t.success, onTap: onRestore)
          else ...[
            _IconBtn(icon: Icons.edit_outlined, color: mq.ink2, onTap: onEdit),
            const SizedBox(width: MqSpacing.xs),
            _IconBtn(
                icon: Icons.delete_outline_rounded,
                color: mq.error,
                onTap: onDelete),
          ],
        ],
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
          width: 34,
          height: 34,
          child: Icon(icon, size: 17, color: color),
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
            child: Icon(Icons.menu_book_outlined, size: 34, color: mq.ink3),
          ),
          const SizedBox(height: MqSpacing.md),
          Text(
            hasFilter ? 'لا توجد مواد بهذه الفلاتر' : 'لا توجد مواد بعد',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: mq.ink2),
          ),
          const SizedBox(height: MqSpacing.xs),
          Text(
            'أضف مادتك الأولى من زر «إضافة مادة»',
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(color: mq.ink3),
          ),
        ],
      ),
    );
  }
}
