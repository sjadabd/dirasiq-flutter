import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/teacher_api_service.dart';
import '../shared/teacher_drawer.dart';
import '../shared/teacher_bottom_nav.dart';
import '../shared/teacher_helpers.dart';
import 'widgets/teacher_course_form_dialog.dart';

/// Teacher → "الكورسات" (show-course.vue) — visual card list.
/// Create / edit of full courses with images stays in the dashboard.
class TeacherCoursesScreen extends StatefulWidget {
  const TeacherCoursesScreen({super.key});
  @override
  State<TeacherCoursesScreen> createState() => _TeacherCoursesScreenState();
}

class _TeacherCoursesScreenState extends State<TeacherCoursesScreen> {
  final _api = TeacherApiService();
  bool _loading = false;
  List<Map<String, dynamic>> _items = [];
  bool? _deletedFilter = false;
  String _search = '';
  final _searchCtl = TextEditingController();

  @override
  void initState() { super.initState(); _fetch(); }
  @override
  void dispose() { _searchCtl.dispose(); super.dispose(); }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await _api.fetchCourses(deleted: _deletedFilter, search: _search.trim().isEmpty ? null : _search.trim(), page: 1, limit: 50);
      final list = res['data'];
      _items = (list is List) ? list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : [];
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّر جلب الكورسات', snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('تأكيد الحذف'),
      content: const Text('سيتم حذف الكورس. يمكن استرجاعه لاحقاً.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
      ],
    ));
    if (ok != true) return;
    try {
      await _api.deleteCourse(c['id'].toString());
      Get.snackbar('تم', 'تم الحذف', snackPosition: SnackPosition.BOTTOM);
      await _fetch();
    } catch (_) { Get.snackbar('خطأ', 'تعذّر الحذف', snackPosition: SnackPosition.BOTTOM); }
  }

  Future<void> _restore(Map<String, dynamic> c) async {
    try {
      await _api.restoreCourse(c['id'].toString());
      Get.snackbar('تم', 'تم الاسترجاع', snackPosition: SnackPosition.BOTTOM);
      await _fetch();
    } catch (_) { Get.snackbar('خطأ', 'تعذّر الاسترجاع', snackPosition: SnackPosition.BOTTOM); }
  }

  Future<void> _openCreateDialog() async {
    final id = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const TeacherCourseFormDialog(),
    );
    if (id != null && mounted) {
      Get.snackbar('تم', 'تم إنشاء الكورس', snackPosition: SnackPosition.BOTTOM);
      // Switch to the "active" filter so the freshly-created course is
      // visible — newly inserted rows have deleted_at IS NULL.
      setState(() => _deletedFilter = false);
      await _fetch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('الكورسات'), actions: [IconButton(onPressed: _loading ? null : _fetch, icon: const Icon(Icons.refresh))]),
      drawer: const TeacherDrawer(),
      bottomNavigationBar: const TeacherBottomNav(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _openCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('إضافة كورس'),
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(onRefresh: _fetch, child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
        TeacherHero(title: 'كورساتي', subtitle: 'إجمالي: ${_items.length}', icon: Icons.school_outlined),
        const SizedBox(height: 16),
        Row(children: [
          StatusChip(label: 'نشطة', selected: _deletedFilter == false, onTap: () { setState(() => _deletedFilter = false); _fetch(); }, color: Colors.green),
          const SizedBox(width: 8),
          StatusChip(label: 'محذوفة', selected: _deletedFilter == true, onTap: () { setState(() => _deletedFilter = true); _fetch(); }, color: Colors.red),
          const SizedBox(width: 8),
          StatusChip(label: 'الكل', selected: _deletedFilter == null, onTap: () { setState(() => _deletedFilter = null); _fetch(); }, color: kNavy),
        ]),
        const SizedBox(height: 10),
        TextField(controller: _searchCtl, onChanged: (v) => setState(() => _search = v),
            onSubmitted: (_) => _fetch(),
            decoration: InputDecoration(hintText: 'بحث في اسم الكورس...', prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true)),
        const SizedBox(height: 14),
        if (_loading)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else if (_items.isEmpty)
          const EmptyState(message: 'لا توجد كورسات. اضغط زر "إضافة كورس" أدناه لإنشاء الكورس الأول.')
        else ..._items.map((c) {
          final isDeleted = c['deleted_at'] != null || c['is_deleted'] == true;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: kNavy.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.book_outlined, color: kNavy, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text((c['course_name'] ?? '—').toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Wrap(spacing: 4, children: [
                    if (c['grade_name'] != null) Chip(visualDensity: VisualDensity.compact, label: Text(c['grade_name'].toString(), style: const TextStyle(fontSize: 10))),
                    if (c['subject_name'] != null) Chip(visualDensity: VisualDensity.compact, label: Text(c['subject_name'].toString(), style: const TextStyle(fontSize: 10))),
                  ]),
                ])),
                if (isDeleted)
                  IconButton(onPressed: () => _restore(c), icon: const Icon(Icons.restore, color: Colors.green))
                else
                  IconButton(onPressed: () => _delete(c), icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20)),
              ]),
              Wrap(spacing: 12, children: [
                _MetaRow(icon: Icons.payments_outlined, text: '${fmtNum(c['price'])} د.ع', color: Colors.green),
                _MetaRow(icon: Icons.group_outlined, text: '${c['seats_count'] ?? 0} مقعد', color: kSky),
                if (c['has_reservation'] == true) _MetaRow(icon: Icons.savings_outlined, text: 'عربون: ${fmtNum(c['reservation_amount'])}', color: kOrange),
              ]),
            ]),
          );
        }),
        const SizedBox(height: 64), // breathing room for FAB
      ])),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 3),
      Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    ]);
  }
}
