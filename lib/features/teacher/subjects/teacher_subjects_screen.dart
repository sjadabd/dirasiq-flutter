import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/teacher_api_service.dart';
import '../shared/teacher_drawer.dart';
import '../shared/teacher_bottom_nav.dart';
import '../shared/teacher_helpers.dart';

/// Teacher → "المواد الدراسية" (show-subjects.vue) — full CRUD.
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
  void initState() { super.initState(); _fetch(); }
  @override
  void dispose() { _searchCtl.dispose(); super.dispose(); }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await _api.fetchSubjects(isDeleted: _deletedFilter, search: _search.trim().isEmpty ? null : _search.trim(), page: 1, limit: 100);
      final list = res['data'];
      _items = (list is List) ? list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : [];
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّر جلب المواد', snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editDialog({Map<String, dynamic>? existing}) async {
    final name = TextEditingController(text: (existing?['name'] ?? '').toString());
    final desc = TextEditingController(text: (existing?['description'] ?? '').toString());
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(existing == null ? 'إضافة مادة' : 'تعديل المادة'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المادة *', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: desc, maxLines: 3, decoration: const InputDecoration(labelText: 'الوصف', border: OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
      ],
    ));
    if (ok != true) return;
    if (name.text.trim().isEmpty) { Get.snackbar('تنبيه', 'اسم المادة مطلوب', snackPosition: SnackPosition.BOTTOM); return; }
    try {
      final payload = {'name': name.text.trim()};
      if (desc.text.trim().isNotEmpty) payload['description'] = desc.text.trim();
      if (existing == null) {
        await _api.createSubject(payload);
        Get.snackbar('تم', 'تمت الإضافة', snackPosition: SnackPosition.BOTTOM);
      } else {
        await _api.updateSubject(existing['id'].toString(), payload);
        Get.snackbar('تم', 'تم التعديل', snackPosition: SnackPosition.BOTTOM);
      }
      await _fetch();
    } catch (_) { Get.snackbar('خطأ', 'تعذّر الحفظ', snackPosition: SnackPosition.BOTTOM); }
  }

  Future<void> _delete(Map<String, dynamic> s) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('تأكيد الحذف'), content: const Text('سيتم حذف المادة. يمكن استرجاعها.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
      ],
    ));
    if (ok != true) return;
    try { await _api.deleteSubject(s['id'].toString()); await _fetch(); Get.snackbar('تم', 'تم الحذف', snackPosition: SnackPosition.BOTTOM); }
    catch (_) { Get.snackbar('خطأ', 'تعذّر الحذف', snackPosition: SnackPosition.BOTTOM); }
  }

  Future<void> _restore(Map<String, dynamic> s) async {
    try { await _api.restoreSubject(s['id'].toString()); await _fetch(); Get.snackbar('تم', 'تم الاسترجاع', snackPosition: SnackPosition.BOTTOM); }
    catch (_) { Get.snackbar('خطأ', 'تعذّر الاسترجاع', snackPosition: SnackPosition.BOTTOM); }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('المواد الدراسية'), actions: [IconButton(onPressed: _loading ? null : _fetch, icon: const Icon(Icons.refresh))]),
      drawer: const TeacherDrawer(),
      bottomNavigationBar: const TeacherBottomNav(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editDialog(), icon: const Icon(Icons.add), label: const Text('إضافة مادة'),
        backgroundColor: kOrange, foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(onRefresh: _fetch, child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
        TeacherHero(title: 'المواد الدراسية', subtitle: 'إجمالي: ${_items.length}', icon: Icons.menu_book_outlined),
        const SizedBox(height: 16),
        Row(children: [
          StatusChip(label: 'نشطة', selected: _deletedFilter == false, onTap: () { setState(() => _deletedFilter = false); _fetch(); }, color: Colors.green),
          const SizedBox(width: 8),
          StatusChip(label: 'محذوفة', selected: _deletedFilter == true, onTap: () { setState(() => _deletedFilter = true); _fetch(); }, color: Colors.red),
          const SizedBox(width: 8),
          StatusChip(label: 'الكل', selected: _deletedFilter == null, onTap: () { setState(() => _deletedFilter = null); _fetch(); }, color: kNavy),
        ]),
        const SizedBox(height: 10),
        TextField(controller: _searchCtl, onChanged: (v) => setState(() => _search = v), onSubmitted: (_) => _fetch(),
            decoration: InputDecoration(hintText: 'بحث في اسم المادة...', prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true)),
        const SizedBox(height: 14),
        if (_loading)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else if (_items.isEmpty)
          const EmptyState(message: 'لا توجد مواد. أضف مادتك الأولى من زر +')
        else ..._items.map((s) {
          final isDeleted = s['deleted_at'] != null || s['is_deleted'] == true;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4))),
            child: Row(children: [
              CircleAvatar(radius: 18, backgroundColor: isDeleted ? Colors.red.withValues(alpha: 0.18) : kSky.withValues(alpha: 0.18),
                  child: Icon(Icons.menu_book_outlined, color: isDeleted ? Colors.red : kSky, size: 18)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((s['name'] ?? '—').toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                if ((s['description'] ?? '').toString().isNotEmpty)
                  Text(s['description'].toString(), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
              ])),
              if (isDeleted)
                IconButton(onPressed: () => _restore(s), icon: const Icon(Icons.restore, color: Colors.green))
              else ...[
                IconButton(onPressed: () => _editDialog(existing: s), icon: const Icon(Icons.edit_outlined, size: 20)),
                IconButton(onPressed: () => _delete(s), icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20)),
              ],
            ]),
          );
        }),
      ])),
    );
  }
}
