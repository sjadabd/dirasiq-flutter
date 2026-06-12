import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/teacher_api_service.dart';
import '../shared/design/teacher_design.dart';
import '../shared/teacher_app_bar.dart';
import '../shared/teacher_drawer.dart';
import '../shared/teacher_helpers.dart' show fmtRelative, initialsOf, fmtIQD;

/// Teacher → "الحجوزات" (Teacher Design System pass).
///
/// Presentation only — `fetchBookings` / `fetchBookingStats` /
/// `fetchSubscriptionCapacity`, the status-aware actions (pre-approve /
/// confirm / reject / reactivate / delete), the year selector, and the status
/// filter are UNCHANGED.
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

  static const _filters = <(String?, String)>[
    (null, 'الكل'),
    ('pending', 'قيد الانتظار'),
    ('pre_approved', 'موافقة أولية'),
    ('confirmed', 'مؤكدة'),
    ('approved', 'مقبولة'),
    ('rejected', 'مرفوضة'),
    ('cancelled', 'ملغاة'),
  ];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final res = await _api.fetchAcademicYears();
      final data =
          (res['data'] is Map) ? Map<String, dynamic>.from(res['data']) : {};
      final years = (data['years'] is List) ? (data['years'] as List) : [];
      _years = years
          .map((y) => (y is Map ? (y['year']?.toString() ?? '') : y.toString()))
          .where((s) => s.isNotEmpty)
          .cast<String>()
          .toList();
      _studyYear = (data['active'] is Map)
          ? data['active']['year']?.toString()
          : (_years.isNotEmpty ? _years.first : null);
      if (mounted) setState(() {});
    } catch (_) {}
    await _fetch();
  }

  Future<void> _fetch() async {
    if (_studyYear == null) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.fetchBookings(
            studyYear: _studyYear!, status: _statusFilter, page: 1, limit: 100),
        _api.fetchBookingStats(_studyYear!),
        _api.fetchSubscriptionCapacity(),
      ]);
      final list = results[0]['data'];
      _items = (list is List)
          ? list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
          : [];
      _pendingCount = ((results[1]['data'] is Map)
          ? (results[1]['data']['pendingBookings'] ?? 0)
          : 0) as int;
      _capacity = (results[2]['data'] is Map)
          ? Map<String, dynamic>.from(results[2]['data'])
          : const {};
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّر جلب الحجوزات',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _promptText(String title,
      {String? hint, bool required = false}) async {
    final ctl = TextEditingController(text: hint ?? '');
    return showDialog<String?>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text(title),
              content: TextField(
                  controller: ctl,
                  maxLines: 3,
                  decoration: const InputDecoration(border: OutlineInputBorder())),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('إلغاء')),
                FilledButton(
                    onPressed: () {
                      if (required && ctl.text.trim().isEmpty) {
                        Get.snackbar('تنبيه', 'الحقل مطلوب',
                            snackPosition: SnackPosition.BOTTOM);
                        return;
                      }
                      Navigator.pop(ctx, ctl.text.trim());
                    },
                    child: const Text('تأكيد')),
              ],
            ));
  }

  Future<void> _preApprove(Map<String, dynamic> b) async {
    final note = await _promptText('موافقة أولية',
        hint: 'مرحباً بكم، يرجى إحضار العربون لتأكيد الحجز');
    if (note == null) return;
    try {
      await _api.preApproveBooking(b['id'].toString(), teacherResponse: note);
      Get.snackbar('تم', 'تمت الموافقة الأولية',
          snackPosition: SnackPosition.BOTTOM);
      await _fetch();
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّرت الموافقة',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _confirm(Map<String, dynamic> b) async {
    final course =
        (b['course'] is Map) ? Map<String, dynamic>.from(b['course']) : const {};
    final hasReservation =
        course['hasReservation'] == true || course['has_reservation'] == true;
    final amount = num.tryParse(
            '${course['reservationAmount'] ?? course['reservation_amount'] ?? 0}') ??
        0;

    final result = await _showConfirmSheet(
        hasReservation: hasReservation, amount: amount);
    if (result == null) return; // cancelled

    try {
      await _api.confirmBooking(
        b['id'].toString(),
        teacherResponse: result.note.isEmpty ? null : result.note,
        reservationPaid: result.paid,
      );
      _toast(hasReservation && !result.paid
          ? 'تم تأكيد الحجز — سيُرسل للطالب طلب دفع العربون'
          : 'تم تأكيد الحجز');
      await _fetch();
    } catch (e) {
      _toast(_apiMessage(e) ?? 'تعذّر التأكيد');
    }
  }

  /// Booking-confirm sheet. When the course has a reservation (عربون) the
  /// teacher chooses whether it was received — mirrors the web dashboard.
  /// Returns null on cancel, else `(paid, note)`.
  Future<({bool paid, String note})?> _showConfirmSheet({
    required bool hasReservation,
    required num amount,
  }) async {
    final noteCtl = TextEditingController();
    bool paid = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Theme(
        data: isDark ? MqTheme.dark() : MqTheme.light(),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(builder: (sheetCtx, setLocal) {
            final mq = sheetCtx.mq;
            final t = sheetCtx.teacher;
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
                                  color: t.successSoft,
                                  borderRadius: MqRadius.brSm),
                              child: Icon(Icons.check_circle_outline,
                                  size: MqSize.iconSm, color: t.success),
                            ),
                            const SizedBox(width: MqSpacing.sm),
                            Expanded(
                              child: Text('تأكيد الحجز',
                                  style: sheetCtx.text.titleMedium),
                            ),
                            InkWell(
                              onTap: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                Navigator.pop(sheetCtx);
                              },
                              customBorder: const CircleBorder(),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child:
                                    Icon(Icons.close_rounded, color: mq.ink3),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: MqSpacing.lg),
                        if (hasReservation) ...[
                          // Reservation amount
                          Container(
                            padding: const EdgeInsets.all(MqSpacing.md),
                            decoration: BoxDecoration(
                                color: mq.accentSoft,
                                borderRadius: MqRadius.brMd,
                                border: Border.all(color: mq.accentLine)),
                            child: Row(
                              children: [
                                Icon(Icons.savings_outlined,
                                    size: MqSize.iconSm, color: mq.accent),
                                const SizedBox(width: MqSpacing.sm),
                                Text('مبلغ العربون',
                                    style: sheetCtx.text.bodyMedium
                                        ?.copyWith(color: mq.ink2)),
                                const Spacer(),
                                Text(fmtIQD(amount),
                                    style: sheetCtx.text.titleSmall
                                        ?.copyWith(color: mq.accent)),
                              ],
                            ),
                          ),
                          const SizedBox(height: MqSpacing.md),
                          // Received toggle
                          Container(
                            padding: const EdgeInsetsDirectional.only(
                                start: MqSpacing.md, end: MqSpacing.xs),
                            decoration: BoxDecoration(
                                color: mq.fill,
                                borderRadius: MqRadius.brMd,
                                border: Border.all(color: mq.line)),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text('تم استلام العربون',
                                      style: sheetCtx.text.bodyMedium),
                                ),
                                Switch(
                                  value: paid,
                                  activeTrackColor: t.success,
                                  onChanged: (v) => setLocal(() => paid = v),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: MqSpacing.sm),
                          if (!paid)
                            Container(
                              padding: const EdgeInsets.all(MqSpacing.md),
                              decoration: BoxDecoration(
                                  color: t.warningSoft,
                                  borderRadius: MqRadius.brMd,
                                  border: Border.all(color: t.warningLine)),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.info_outline,
                                      size: MqSize.iconSm, color: t.warning),
                                  const SizedBox(width: MqSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      'إذا لم يُستلم العربون بعد، اترك المفتاح مغلقاً — '
                                      'وسيُرسل للطالب طلب دفع العربون.',
                                      style: sheetCtx.text.bodySmall?.copyWith(
                                          color: mq.ink2, height: 1.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: MqSpacing.md),
                        ] else
                          Padding(
                            padding: const EdgeInsets.only(bottom: MqSpacing.md),
                            child: Text(
                              'سيتم تثبيت الحجز. لا يوجد عربون مطلوب لهذه الدورة.',
                              style: sheetCtx.text.bodyMedium
                                  ?.copyWith(color: mq.ink2),
                            ),
                          ),
                        TextField(
                          controller: noteCtl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'رسالة للطالب (اختياري)',
                            hintText: 'مثال: تم تثبيت حجزك، نراك في أول حصة',
                          ),
                        ),
                        const SizedBox(height: MqSpacing.xl),
                        MqButton(
                          label: 'تأكيد الحجز',
                          icon: Icons.check_rounded,
                          onPressed: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            Navigator.pop(sheetCtx, true);
                          },
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

    final note = noteCtl.text.trim();
    // Dispose after the sheet's exit animation (avoids the ChangeNotifier
    // "used after dispose" red screen).
    Future.delayed(const Duration(milliseconds: 500), noteCtl.dispose);

    if (confirmed != true) return null;
    return (paid: hasReservation ? paid : true, note: note);
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
      ));
  }

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

  Future<void> _reject(Map<String, dynamic> b) async {
    final reason = await _promptText('رفض الحجز', hint: 'سبب الرفض', required: true);
    if (reason == null || reason.isEmpty) return;
    try {
      await _api.rejectBooking(b['id'].toString(), rejectionReason: reason);
      Get.snackbar('تم', 'تم رفض الحجز', snackPosition: SnackPosition.BOTTOM);
      await _fetch();
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّر الرفض', snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _reactivate(Map<String, dynamic> b) async {
    try {
      await _api.reactivateBooking(b['id'].toString());
      Get.snackbar('تم', 'تمت إعادة التفعيل',
          snackPosition: SnackPosition.BOTTOM);
      await _fetch();
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّرت إعادة التفعيل',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _delete(Map<String, dynamic> b) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('تأكيد الحذف'),
              content: const Text('سيتم حذف الحجز نهائياً.'),
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
      await _api.deleteBooking(b['id'].toString());
      Get.snackbar('تم', 'تم الحذف', snackPosition: SnackPosition.BOTTOM);
      await _fetch();
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّر الحذف', snackPosition: SnackPosition.BOTTOM);
    }
  }

  static (String, TeacherTone) statusMeta(String s) {
    switch (s) {
      case 'pending':
        return ('قيد الانتظار', TeacherTone.warning);
      case 'pre_approved':
        return ('موافقة أولية', TeacherTone.info);
      case 'confirmed':
        return ('مؤكدة', TeacherTone.success);
      case 'approved':
        return ('مقبولة', TeacherTone.success);
      case 'rejected':
        return ('مرفوضة', TeacherTone.danger);
      case 'cancelled':
        return ('ملغاة', TeacherTone.neutral);
      default:
        return (s, TeacherTone.neutral);
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
              title: 'الحجوزات',
              actions: [_RefreshAction(loading: _loading, onTap: _fetch)],
            ),
            drawer: const TeacherDrawer(),
            body: RefreshIndicator(
              onRefresh: _fetch,
              color: mq.accent,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    MqSpacing.lg, MqSpacing.lg, MqSpacing.lg, MqSpacing.xl),
                children: [
                  _hero(context),
                  const SizedBox(height: MqSpacing.md),
                  _capacityCard(context),
                  const SizedBox(height: MqSpacing.lg),
                  _filterRow(context),
                  const SizedBox(height: MqSpacing.md),
                  if (_loading && _items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(MqSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_items.isEmpty)
                    _EmptyState(hasFilter: _statusFilter != null)
                  else
                    ..._items.map((b) {
                      final status = (b['status'] ?? '').toString();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: MqSpacing.md),
                        child: _BookingCard(
                          booking: b,
                          status: status,
                          onPreApprove: () => _preApprove(b),
                          onConfirm: () => _confirm(b),
                          onReject: () => _reject(b),
                          onReactivate: () => _reactivate(b),
                          onDelete: () => _delete(b),
                        ),
                      );
                    }),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ---- hero -----------------------------------------------------------------

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
            child: const Icon(Icons.assignment_turned_in_outlined,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: MqSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('طلبات الحجز',
                    style: context.text.titleMedium?.copyWith(color: t.heroInk)),
                const SizedBox(height: 2),
                Text('السنة: ${_studyYear ?? '—'}',
                    style:
                        context.text.labelSmall?.copyWith(color: t.heroInk2)),
              ],
            ),
          ),
          if (_pendingCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: MqSpacing.sm, vertical: 3),
              decoration: BoxDecoration(
                color: t.heroTile,
                borderRadius: MqRadius.brPill,
                border: Border.all(color: t.heroLine),
              ),
              child: Text('$_pendingCount معلّقة',
                  style: context.text.labelSmall?.copyWith(color: t.heroInk)),
            ),
          if (_years.length > 1) ...[
            const SizedBox(width: MqSpacing.sm),
            _yearSelector(context),
          ],
        ],
      ),
    );
  }

  Widget _yearSelector(BuildContext context) {
    final t = context.teacher;
    return PopupMenuButton<String>(
      initialValue: _studyYear,
      onSelected: (v) async {
        setState(() => _studyYear = v);
        await _fetch();
      },
      itemBuilder: (ctx) =>
          _years.map((y) => PopupMenuItem(value: y, child: Text(y))).toList(),
      child: Container(
        padding: const EdgeInsets.all(MqSpacing.sm),
        decoration: BoxDecoration(
          color: t.heroTile,
          borderRadius: MqRadius.brPill,
          border: Border.all(color: t.heroLine),
        ),
        child: Icon(Icons.expand_more_rounded, color: t.heroInk, size: 18),
      ),
    );
  }

  // ---- capacity -------------------------------------------------------------

  Widget _capacityCard(BuildContext context) {
    final mq = context.mq;
    final t = context.teacher;
    final current = num.tryParse((_capacity['currentStudents'] ?? 0).toString()) ?? 0;
    final max = num.tryParse((_capacity['maxStudents'] ?? 0).toString()) ?? 0;
    final remaining = num.tryParse((_capacity['remaining'] ?? 0).toString()) ?? 0;
    final pct = max > 0 ? (current / max).clamp(0, 1).toDouble() : 0.0;
    final color = pct > 0.9 ? mq.error : (pct > 0.7 ? t.warning : mq.accent);

    return MqCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: mq.accentSoft, borderRadius: MqRadius.brSm),
                child: Icon(Icons.groups_2_outlined,
                    size: MqSize.iconSm, color: mq.accent),
              ),
              const SizedBox(width: MqSpacing.sm),
              Text('سعة باقة الاشتراك', style: context.text.titleSmall),
              const Spacer(),
              Text('$current / $max',
                  style: MqTypography.mono(
                      color: mq.ink, size: 14, weight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: MqSpacing.sm),
          ClipRRect(
            borderRadius: MqRadius.brPill,
            child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                color: color,
                backgroundColor: mq.fill2),
          ),
          const SizedBox(height: MqSpacing.xs),
          Text('متبقّي: $remaining طالب',
              style: context.text.labelSmall?.copyWith(color: mq.ink3)),
        ],
      ),
    );
  }

  // ---- filters --------------------------------------------------------------

  Widget _filterRow(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (value, label) in _filters) ...[
            MqChip(
              label: label,
              selected: _statusFilter == value,
              onTap: () {
                setState(() => _statusFilter = value);
                _fetch();
              },
            ),
            const SizedBox(width: MqSpacing.sm),
          ],
        ],
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

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.status,
    required this.onPreApprove,
    required this.onConfirm,
    required this.onReject,
    required this.onReactivate,
    required this.onDelete,
  });
  final Map<String, dynamic> booking;
  final String status;
  final VoidCallback onPreApprove, onConfirm, onReject, onReactivate, onDelete;

  ({Color base, Color soft, Color line}) _tone(BuildContext context, TeacherTone t) {
    final mq = context.mq;
    final tk = context.teacher;
    return switch (t) {
      TeacherTone.warning => (base: tk.warning, soft: tk.warningSoft, line: tk.warningLine),
      TeacherTone.info => (base: tk.info, soft: tk.infoSoft, line: tk.infoLine),
      TeacherTone.success => (base: tk.success, soft: tk.successSoft, line: tk.successLine),
      TeacherTone.danger => (base: tk.danger, soft: tk.dangerSoft, line: tk.dangerLine),
      TeacherTone.neutral => (base: mq.ink2, soft: mq.fill2, line: mq.line),
    };
  }

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final student = (booking['student'] is Map)
        ? Map<String, dynamic>.from(booking['student'])
        : {};
    final course = (booking['course'] is Map)
        ? Map<String, dynamic>.from(booking['course'])
        : {};
    final studentName = (student['name'] ?? '—').toString();
    final courseName =
        (course['courseName'] ?? course['name'] ?? '—').toString();
    final gradeName = (course['gradeName'] ?? course['grade'] ?? '').toString();
    final msg = (booking['studentMessage'] ?? '').toString();
    final teacherResp = (booking['teacherResponse'] ?? '').toString();
    final rejectReason = (booking['rejectionReason'] ?? '').toString();

    final (statusLabel, statusTone) =
        _TeacherBookingsScreenState.statusMeta(status);
    final st = _tone(context, statusTone);

    final canPreApprove = status == 'pending';
    final canConfirm = status == 'pre_approved';
    final canReject = status == 'pending' || status == 'pre_approved';
    final canReactivate = status == 'rejected' || status == 'cancelled';
    final canDelete =
        status == 'pending' || status == 'rejected' || status == 'cancelled';

    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: st.soft,
                  shape: BoxShape.circle,
                  border: Border.all(color: st.line),
                ),
                alignment: Alignment.center,
                child: Text(initialsOf(studentName),
                    style: MqTypography.mono(
                        color: st.base, size: 14, weight: FontWeight.w700)),
              ),
              const SizedBox(width: MqSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(studentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(fmtRelative(booking['createdAt']),
                        style:
                            context.text.labelSmall?.copyWith(color: mq.ink3)),
                  ],
                ),
              ),
              const SizedBox(width: MqSpacing.sm),
              TeacherStatusPill(label: statusLabel, tone: statusTone),
            ],
          ),
          const SizedBox(height: MqSpacing.sm),
          Container(
            padding: const EdgeInsets.all(MqSpacing.sm),
            decoration:
                BoxDecoration(color: mq.fill, borderRadius: MqRadius.brMd),
            child: Row(
              children: [
                Icon(Icons.book_outlined, size: 16, color: mq.accent),
                const SizedBox(width: MqSpacing.sm),
                Expanded(
                  child: Text(courseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                if (gradeName.isNotEmpty)
                  MqBadge(label: gradeName, tone: MqBadgeTone.neutral),
              ],
            ),
          ),
          if (msg.isNotEmpty) ...[
            const SizedBox(height: MqSpacing.sm),
            _MsgBox(label: 'رسالة الطالب', text: msg, tone: TeacherTone.info),
          ],
          if (teacherResp.isNotEmpty) ...[
            const SizedBox(height: MqSpacing.xs),
            _MsgBox(label: 'ردك', text: teacherResp, tone: TeacherTone.warning),
          ],
          if (rejectReason.isNotEmpty) ...[
            const SizedBox(height: MqSpacing.xs),
            _MsgBox(
                label: 'سبب الرفض',
                text: rejectReason,
                tone: TeacherTone.danger),
          ],
          if (canPreApprove ||
              canConfirm ||
              canReject ||
              canReactivate ||
              canDelete) ...[
            const SizedBox(height: MqSpacing.md),
            Wrap(
              spacing: MqSpacing.sm,
              runSpacing: MqSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (canPreApprove)
                  _ActionBtn(
                      label: 'موافقة أولية',
                      icon: Icons.thumb_up_outlined,
                      tone: TeacherTone.info,
                      onTap: onPreApprove),
                if (canConfirm)
                  _ActionBtn(
                      label: 'تأكيد',
                      icon: Icons.check_circle_outline,
                      tone: TeacherTone.success,
                      onTap: onConfirm),
                if (canReject)
                  _ActionBtn(
                      label: 'رفض',
                      icon: Icons.close_rounded,
                      tone: TeacherTone.danger,
                      onTap: onReject),
                if (canReactivate)
                  _ActionBtn(
                      label: 'إعادة تفعيل',
                      icon: Icons.refresh_rounded,
                      tone: TeacherTone.neutral,
                      onTap: onReactivate),
                if (canDelete)
                  InkWell(
                    onTap: onDelete,
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(MqSpacing.xs),
                      child: Icon(Icons.delete_outline_rounded,
                          size: 20, color: mq.error),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn(
      {required this.label,
      required this.icon,
      required this.tone,
      required this.onTap});
  final String label;
  final IconData icon;
  final TeacherTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final t = context.teacher;
    final (base, soft) = switch (tone) {
      TeacherTone.info => (t.info, t.infoSoft),
      TeacherTone.success => (t.success, t.successSoft),
      TeacherTone.danger => (t.danger, t.dangerSoft),
      TeacherTone.warning => (t.warning, t.warningSoft),
      TeacherTone.neutral => (mq.ink2, mq.fill2),
    };
    return Material(
      color: soft,
      borderRadius: MqRadius.brMd,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: MqSpacing.md, vertical: MqSpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: base),
              const SizedBox(width: MqSpacing.xs),
              Text(label,
                  style: context.text.labelMedium
                      ?.copyWith(color: base, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MsgBox extends StatelessWidget {
  const _MsgBox(
      {required this.label, required this.text, required this.tone});
  final String label, text;
  final TeacherTone tone;
  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final t = context.teacher;
    final (base, soft, line) = switch (tone) {
      TeacherTone.info => (t.info, t.infoSoft, t.infoLine),
      TeacherTone.success => (t.success, t.successSoft, t.successLine),
      TeacherTone.danger => (t.danger, t.dangerSoft, t.dangerLine),
      TeacherTone.warning => (t.warning, t.warningSoft, t.warningLine),
      TeacherTone.neutral => (mq.ink2, mq.fill2, mq.line),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MqSpacing.sm),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: MqRadius.brMd,
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: context.text.labelSmall
                  ?.copyWith(color: base, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(text, style: context.text.bodySmall),
        ],
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
            child: Icon(Icons.assignment_turned_in_outlined,
                size: 34, color: mq.ink3),
          ),
          const SizedBox(height: MqSpacing.md),
          Text(
            hasFilter ? 'لا توجد حجوزات بهذه الفلاتر' : 'لا توجد حجوزات بعد',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: mq.ink2),
          ),
        ],
      ),
    );
  }
}
