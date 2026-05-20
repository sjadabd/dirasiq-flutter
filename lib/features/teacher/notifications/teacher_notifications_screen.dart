import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/teacher_api_service.dart';
import '../shared/teacher_drawer.dart';
import '../shared/teacher_bottom_nav.dart';
import '../shared/teacher_helpers.dart';

/// Teacher → "الإشعارات" (show-notifications.vue).
class TeacherNotificationsScreen extends StatefulWidget {
  const TeacherNotificationsScreen({super.key});
  @override
  State<TeacherNotificationsScreen> createState() => _TeacherNotificationsScreenState();
}

class _TeacherNotificationsScreenState extends State<TeacherNotificationsScreen> {
  final _api = TeacherApiService();
  bool _loading = false;
  List<Map<String, dynamic>> _items = [];
  String? _subType;
  String _search = '';
  final _searchCtl = TextEditingController();

  static const _subTypes = [
    {'value': null, 'label': 'الكل'},
    {'value': 'homework', 'label': 'واجب'},
    {'value': 'message', 'label': 'رسالة'},
    {'value': 'report', 'label': 'تقرير'},
    {'value': 'notice', 'label': 'تبليغ'},
    {'value': 'installments', 'label': 'أقساط'},
    {'value': 'attendance', 'label': 'حضور'},
    {'value': 'daily_summary', 'label': 'ملخص يومي'},
  ];

  @override
  void initState() { super.initState(); _fetch(); }
  @override
  void dispose() { _searchCtl.dispose(); super.dispose(); }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await _api.fetchNotifications(subType: _subType, q: _search.trim().isEmpty ? null : _search.trim(), page: 1, limit: 100);
      final list = res['data'];
      _items = (list is List) ? list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : [];
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّر جلب الإشعارات', snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openComposer() async {
    final title = TextEditingController();
    final msg = TextEditingController();
    String mode = 'all_students_of_teacher';
    String? subType;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
      title: const Text('إرسال إشعار جديد'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'العنوان *', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: msg, maxLines: 4, decoration: const InputDecoration(labelText: 'نص الرسالة *', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: subType,
          decoration: const InputDecoration(labelText: 'النوع', border: OutlineInputBorder()),
          items: [for (final s in _subTypes.where((x) => x['value'] != null)) DropdownMenuItem(value: s['value'] as String, child: Text(s['label'] as String))],
          onChanged: (v) => setLocal(() => subType = v),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: mode,
          decoration: const InputDecoration(labelText: 'المستلمون', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'all_students_of_teacher', child: Text('كل طلابي')),
          ],
          onChanged: (v) => setLocal(() => mode = v ?? mode),
        ),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إرسال')),
      ],
    )));
    if (ok != true) return;
    if (title.text.trim().isEmpty || msg.text.trim().isEmpty) {
      Get.snackbar('تنبيه', 'العنوان والرسالة مطلوبان', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    try {
      final payload = <String, dynamic>{
        'type': 'teacher_message',
        'title': title.text.trim(),
        'message': msg.text.trim(),
        'recipients': {'mode': mode},
        'attachments': {},
        'priority': 'medium',
      };
      if (subType != null) payload['subType'] = subType;
      await _api.createNotification(payload);
      Get.snackbar('تم', 'تم إرسال الإشعار', snackPosition: SnackPosition.BOTTOM);
      await _fetch();
    } catch (e) {
      Get.snackbar('خطأ', e.toString(), snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _delete(Map<String, dynamic> n) async {
    final id = n['id']?.toString();
    if (id == null) return;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('تأكيد الحذف'),
      content: const Text('سيتم حذف هذا الإشعار.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
      ],
    ));
    if (ok != true) return;
    try {
      await _api.deleteNotification(id);
      Get.snackbar('تم', 'تم الحذف', snackPosition: SnackPosition.BOTTOM);
      await _fetch();
    } catch (_) { Get.snackbar('خطأ', 'تعذّر الحذف', snackPosition: SnackPosition.BOTTOM); }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [IconButton(onPressed: _loading ? null : _fetch, icon: const Icon(Icons.refresh))],
      ),
      drawer: const TeacherDrawer(),
      bottomNavigationBar: const TeacherBottomNav(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openComposer,
        icon: const Icon(Icons.send_outlined),
        label: const Text('إشعار جديد'),
        backgroundColor: kOrange, foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), children: [
          const TeacherHero(title: 'إشعارات المعلم', subtitle: 'إرسال وعرض الإشعارات للطلاب', icon: Icons.notifications_outlined),
          const SizedBox(height: 16),

          SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final s in _subTypes) Padding(padding: const EdgeInsets.only(left: 8),
              child: StatusChip(label: s['label'] as String, selected: _subType == s['value'],
                  onTap: () { setState(() => _subType = s['value']); _fetch(); },
                  color: kNavy),
            ),
          ])),
          const SizedBox(height: 10),
          TextField(
            controller: _searchCtl,
            onChanged: (v) => setState(() => _search = v),
            onSubmitted: (_) => _fetch(),
            decoration: InputDecoration(hintText: 'بحث في العنوان أو الرسالة...', prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true),
          ),
          const SizedBox(height: 16),

          if (_loading)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (_items.isEmpty)
            const EmptyState(message: 'لا توجد إشعارات بعد')
          else ..._items.map((n) {
            final data = (n['data'] is Map) ? Map<String, dynamic>.from(n['data']) : {};
            final recipients = (data['recipients'] is Map) ? Map<String, dynamic>.from(data['recipients']) : {};
            final mode = (recipients['mode'] ?? n['recipient_type'] ?? '').toString();
            final count = recipients['studentCount'];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: kNavy.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.notifications_outlined, size: 18, color: kNavy),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text((n['title'] ?? '—').toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(fmtRelative(n['sent_at'] ?? n['created_at']), style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  ])),
                  IconButton(onPressed: () => _delete(n), icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18)),
                ]),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: kSky.withValues(alpha: 0.06),
                      border: const Border(right: BorderSide(color: kSky, width: 3)),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text((n['message'] ?? '').toString(), style: const TextStyle(fontSize: 13)),
                ),
                if (mode.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(spacing: 6, children: [
                  Chip(visualDensity: VisualDensity.compact, label: Text(_modeLabel(mode), style: const TextStyle(fontSize: 10))),
                  if (count != null) Chip(visualDensity: VisualDensity.compact, label: Text('$count طالب', style: const TextStyle(fontSize: 10))),
                ])),
              ]),
            );
          }),
        ]),
      ),
    );
  }

  String _modeLabel(String m) {
    switch (m) {
      case 'all_students_of_teacher': return 'كل طلابي';
      case 'students_of_course': return 'طلاب الكورس';
      case 'students_of_session': return 'طلاب الجلسة';
      case 'specific_students': return 'طلاب محددون';
      case 'all': return 'الكل';
      default: return m;
    }
  }
}
