import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/teacher_api_service.dart';
import '../shared/teacher_drawer.dart';
import '../shared/teacher_bottom_nav.dart';
import '../shared/teacher_helpers.dart';

/// Teacher → "الحجوزات" (show-bookings.vue).
/// Status-aware actions: pre-approve / confirm / reject / reactivate / delete.
class TeacherBookingsScreen extends StatefulWidget {
  const TeacherBookingsScreen({super.key});
  @override
  State<TeacherBookingsScreen> createState() => _TeacherBookingsScreenState();
}

class _TeacherBookingsScreenState extends State<TeacherBookingsScreen> {
  final _api = TeacherApiService();
  List<String> _years = [];
  String? _studyYear;
  bool _loading = false;
  List<Map<String, dynamic>> _items = [];
  int _pendingCount = 0;
  Map<String, dynamic> _capacity = const {};
  String? _statusFilter;

  static const _statuses = [
    {'value': null, 'label': 'الكل', 'color': Color(0xFF0B2545)},
    {'value': 'pending', 'label': 'قيد الانتظار', 'color': kOrange},
    {'value': 'pre_approved', 'label': 'موافقة أولية', 'color': kSky},
    {'value': 'confirmed', 'label': 'مؤكدة', 'color': Colors.green},
    {'value': 'approved', 'label': 'مقبولة', 'color': Colors.teal},
    {'value': 'rejected', 'label': 'مرفوضة', 'color': Colors.red},
    {'value': 'cancelled', 'label': 'ملغاة', 'color': Colors.grey},
  ];

  @override
  void initState() { super.initState(); _bootstrap(); }

  Future<void> _bootstrap() async {
    try {
      final res = await _api.fetchAcademicYears();
      final data = (res['data'] is Map) ? Map<String, dynamic>.from(res['data']) : {};
      final years = (data['years'] is List) ? (data['years'] as List) : [];
      _years = years.map((y) => (y is Map ? (y['year']?.toString() ?? '') : y.toString())).where((s) => s.isNotEmpty).cast<String>().toList();
      _studyYear = (data['active'] is Map) ? data['active']['year']?.toString() : (_years.isNotEmpty ? _years.first : null);
      if (mounted) setState(() {});
    } catch (_) {}
    await _fetch();
  }

  Future<void> _fetch() async {
    if (_studyYear == null) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.fetchBookings(studyYear: _studyYear!, status: _statusFilter, page: 1, limit: 100),
        _api.fetchBookingStats(_studyYear!),
        _api.fetchSubscriptionCapacity(),
      ]);
      final list = results[0]['data'];
      _items = (list is List) ? list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : [];
      _pendingCount = ((results[1]['data'] is Map) ? (results[1]['data']['pendingBookings'] ?? 0) : 0) as int;
      _capacity = (results[2]['data'] is Map) ? Map<String, dynamic>.from(results[2]['data']) : const {};
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّر جلب الحجوزات', snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _promptText(String title, {String? hint, bool required = false}) async {
    final ctl = TextEditingController(text: hint ?? '');
    return showDialog<String?>(context: context, builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: ctl, maxLines: 3, decoration: const InputDecoration(border: OutlineInputBorder())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        FilledButton(onPressed: () {
          if (required && ctl.text.trim().isEmpty) {
            Get.snackbar('تنبيه', 'الحقل مطلوب', snackPosition: SnackPosition.BOTTOM);
            return;
          }
          Navigator.pop(ctx, ctl.text.trim());
        }, child: const Text('تأكيد')),
      ],
    ));
  }

  Future<void> _preApprove(Map<String, dynamic> b) async {
    final note = await _promptText('موافقة أولية', hint: 'مرحباً بكم، يرجى إحضار العربون لتأكيد الحجز');
    if (note == null) return;
    try {
      await _api.preApproveBooking(b['id'].toString(), teacherResponse: note);
      Get.snackbar('تم', 'تمت الموافقة الأولية', snackPosition: SnackPosition.BOTTOM);
      await _fetch();
    } catch (_) { Get.snackbar('خطأ', 'تعذّرت الموافقة', snackPosition: SnackPosition.BOTTOM); }
  }

  Future<void> _confirm(Map<String, dynamic> b) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('تأكيد الحجز'),
      content: const Text('هل تم استلام العربون؟ سيتم تثبيت الحجز.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد')),
      ],
    ));
    if (ok != true) return;
    try {
      await _api.confirmBooking(b['id'].toString(), reservationPaid: true);
      Get.snackbar('تم', 'تم تأكيد الحجز', snackPosition: SnackPosition.BOTTOM);
      await _fetch();
    } catch (_) { Get.snackbar('خطأ', 'تعذّر التأكيد', snackPosition: SnackPosition.BOTTOM); }
  }

  Future<void> _reject(Map<String, dynamic> b) async {
    final reason = await _promptText('رفض الحجز', hint: 'سبب الرفض', required: true);
    if (reason == null || reason.isEmpty) return;
    try {
      await _api.rejectBooking(b['id'].toString(), rejectionReason: reason);
      Get.snackbar('تم', 'تم رفض الحجز', snackPosition: SnackPosition.BOTTOM);
      await _fetch();
    } catch (_) { Get.snackbar('خطأ', 'تعذّر الرفض', snackPosition: SnackPosition.BOTTOM); }
  }

  Future<void> _reactivate(Map<String, dynamic> b) async {
    try {
      await _api.reactivateBooking(b['id'].toString());
      Get.snackbar('تم', 'تمت إعادة التفعيل', snackPosition: SnackPosition.BOTTOM);
      await _fetch();
    } catch (_) { Get.snackbar('خطأ', 'تعذّرت إعادة التفعيل', snackPosition: SnackPosition.BOTTOM); }
  }

  Future<void> _delete(Map<String, dynamic> b) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('تأكيد الحذف'),
      content: const Text('سيتم حذف الحجز نهائياً.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
      ],
    ));
    if (ok != true) return;
    try {
      await _api.deleteBooking(b['id'].toString());
      Get.snackbar('تم', 'تم الحذف', snackPosition: SnackPosition.BOTTOM);
      await _fetch();
    } catch (_) { Get.snackbar('خطأ', 'تعذّر الحذف', snackPosition: SnackPosition.BOTTOM); }
  }

  Color _statusColor(String? s) => _statuses.firstWhere((x) => x['value'] == s, orElse: () => _statuses[0])['color'] as Color;
  String _statusLabel(String? s) => _statuses.firstWhere((x) => x['value'] == s, orElse: () => _statuses[0])['label'] as String;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentStudents = num.tryParse((_capacity['currentStudents'] ?? 0).toString()) ?? 0;
    final maxStudents = num.tryParse((_capacity['maxStudents'] ?? 0).toString()) ?? 0;
    final remaining = num.tryParse((_capacity['remaining'] ?? 0).toString()) ?? 0;
    final pct = maxStudents > 0 ? (currentStudents / maxStudents).clamp(0, 1).toDouble() : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الحجوزات'),
        actions: [IconButton(onPressed: _loading ? null : _fetch, icon: const Icon(Icons.refresh))],
      ),
      drawer: const TeacherDrawer(),
      bottomNavigationBar: const TeacherBottomNav(),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
          TeacherHero(title: 'طلبات الحجز', subtitle: 'السنة: ${_studyYear ?? '—'} · معلّقة: $_pendingCount',
              icon: Icons.assignment_turned_in_outlined),
          const SizedBox(height: 16),

          // Capacity strip
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.group_outlined, size: 18, color: kSky),
                const SizedBox(width: 8),
                const Text('سعة باقة الاشتراك', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('$currentStudents / $maxStudents', style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: pct, minHeight: 8,
                    color: pct > 0.9 ? Colors.red : (pct > 0.7 ? kOrange : kSky),
                    backgroundColor: Colors.grey[200]),
              ),
              const SizedBox(height: 4),
              Text('متبقي: $remaining طالب', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ]),
          ),
          const SizedBox(height: 16),

          SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final s in _statuses) Padding(padding: const EdgeInsets.only(left: 8),
              child: StatusChip(label: s['label'] as String, selected: _statusFilter == s['value'],
                  onTap: () { setState(() => _statusFilter = s['value'] as String?); _fetch(); },
                  color: s['color'] as Color),
            ),
          ])),
          const SizedBox(height: 12),

          if (_loading)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (_items.isEmpty)
            const EmptyState(message: 'لا توجد حجوزات بهذه الفلاتر')
          else ..._items.map((b) {
            final status = (b['status'] ?? '').toString();
            final canPreApprove = status == 'pending';
            final canConfirm = status == 'pre_approved';
            final canReject = status == 'pending' || status == 'pre_approved';
            final canReactivate = status == 'rejected' || status == 'cancelled';
            final canDelete = status == 'pending' || status == 'rejected' || status == 'cancelled';
            return _BookingTile(
              booking: b,
              statusColor: _statusColor(status),
              statusLabel: _statusLabel(status),
              canPreApprove: canPreApprove, canConfirm: canConfirm,
              canReject: canReject, canReactivate: canReactivate, canDelete: canDelete,
              onPreApprove: () => _preApprove(b),
              onConfirm: () => _confirm(b),
              onReject: () => _reject(b),
              onReactivate: () => _reactivate(b),
              onDelete: () => _delete(b),
            );
          }),
        ]),
      ),
    );
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile({
    required this.booking, required this.statusColor, required this.statusLabel,
    required this.canPreApprove, required this.canConfirm, required this.canReject,
    required this.canReactivate, required this.canDelete,
    required this.onPreApprove, required this.onConfirm, required this.onReject,
    required this.onReactivate, required this.onDelete,
  });
  final Map<String, dynamic> booking;
  final Color statusColor;
  final String statusLabel;
  final bool canPreApprove, canConfirm, canReject, canReactivate, canDelete;
  final VoidCallback onPreApprove, onConfirm, onReject, onReactivate, onDelete;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final student = (booking['student'] is Map) ? Map<String, dynamic>.from(booking['student']) : {};
    final course = (booking['course'] is Map) ? Map<String, dynamic>.from(booking['course']) : {};
    final studentName = (student['name'] ?? '—').toString();
    final courseName = (course['courseName'] ?? course['name'] ?? '—').toString();
    final gradeName = (course['gradeName'] ?? course['grade'] ?? '').toString();
    final msg = (booking['studentMessage'] ?? '').toString();
    final teacherResp = (booking['teacherResponse'] ?? '').toString();
    final rejectReason = (booking['rejectionReason'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 20, backgroundColor: statusColor.withValues(alpha: 0.18),
              child: Text(initialsOf(studentName), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(fmtRelative(booking['createdAt']), style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ]),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: kNavy.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            const Icon(Icons.book_outlined, size: 16, color: kNavy),
            const SizedBox(width: 6),
            Expanded(child: Text(courseName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (gradeName.isNotEmpty) Text(gradeName, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ]),
        ),
        if (msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: _MsgBox(label: 'رسالة الطالب', text: msg, color: kSky)),
        if (teacherResp.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: _MsgBox(label: 'ردك', text: teacherResp, color: kOrange)),
        if (rejectReason.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: _MsgBox(label: 'سبب الرفض', text: rejectReason, color: Colors.red)),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (canPreApprove) FilledButton.tonalIcon(onPressed: onPreApprove, icon: const Icon(Icons.thumb_up_outlined, size: 16), label: const Text('موافقة أولية', style: TextStyle(fontSize: 12)), style: FilledButton.styleFrom(visualDensity: VisualDensity.compact)),
          if (canConfirm) FilledButton.tonalIcon(onPressed: onConfirm, icon: const Icon(Icons.check_circle_outline, size: 16), label: const Text('تأكيد', style: TextStyle(fontSize: 12)), style: FilledButton.styleFrom(backgroundColor: Colors.green.withValues(alpha: 0.12), foregroundColor: Colors.green, visualDensity: VisualDensity.compact)),
          if (canReject) FilledButton.tonalIcon(onPressed: onReject, icon: const Icon(Icons.close, size: 16), label: const Text('رفض', style: TextStyle(fontSize: 12)), style: FilledButton.styleFrom(backgroundColor: Colors.red.withValues(alpha: 0.12), foregroundColor: Colors.red, visualDensity: VisualDensity.compact)),
          if (canReactivate) FilledButton.tonalIcon(onPressed: onReactivate, icon: const Icon(Icons.refresh, size: 16), label: const Text('إعادة تفعيل', style: TextStyle(fontSize: 12)), style: FilledButton.styleFrom(visualDensity: VisualDensity.compact)),
          if (canDelete) IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20)),
        ]),
      ]),
    );
  }
}

class _MsgBox extends StatelessWidget {
  const _MsgBox({required this.label, required this.text, required this.color});
  final String label, text;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(text, style: const TextStyle(fontSize: 12)),
      ]),
    );
  }
}
