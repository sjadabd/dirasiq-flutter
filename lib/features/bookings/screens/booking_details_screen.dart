// Student → Booking details (MulhimIQ design-system pass). Route
// /booking-details (arg: bookingId).
//
// Backed by ApiService.fetchBookingDetails → GET /student/bookings/:id. The
// cancel (cancelBooking) and reactivate (reactivateBooking) flows, the booking
// status semantics, and navigation are UNCHANGED — only the presentation was
// restyled. There is no payment-status field and no course-hub / payment
// action in the booking object, so "إكمال الدفع" / "دخول بيئة الدورة" are not
// shown (never invent actions). Every field/section renders only when the
// backend provides it.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:mulhimiq/core/config/app_config.dart';
import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/core/utils/money.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';
import 'package:mulhimiq/shared/widgets/app_network_image.dart';

class BookingDetailsScreen extends StatefulWidget {
  final String? bookingId;
  const BookingDetailsScreen({super.key, this.bookingId});

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

  String? _resolveBookingId() {
    return widget.bookingId ??
        (Get.arguments is String ? Get.arguments as String : null) ??
        (ModalRoute.of(context)?.settings.arguments as String?);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final id = _resolveBookingId();
    if (id == null) {
      setState(() {
        _loading = false;
        _error = 'معرف الحجز غير متوفر';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.fetchBookingDetails(id);
      if (!mounted) return;
      setState(() {
        _data = res['data'] ?? res;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذّر تحميل تفاصيل الحجز';
        _loading = false;
      });
    }
  }

  // ─── actions (UNCHANGED endpoints) ──────────────────────────────────────────

  Future<void> _cancel() async {
    final id = _data?['id']?.toString();
    if (id == null) return;
    final reason = await _askForReason();
    if (reason == null) return;
    try {
      await _api.cancelBooking(bookingId: id, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء الحجز'), behavior: SnackBarBehavior.floating),
      );
      _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر إلغاء الحجز'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _reactivate() async {
    final id = _data?['id']?.toString();
    if (id == null) return;
    try {
      final res = await _api.reactivateBooking(id);
      if (!mounted) return;
      final msg = (res['message'] ?? 'تم إعادة إرسال الطلب').toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
      final warning = res['warning'];
      if (warning is Map<String, dynamic>) {
        final wMsg = warning['message']?.toString() ?? 'تنبيه';
        final note = warning['note']?.toString();
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(wMsg),
            content: note != null ? Text(note) : null,
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً'))],
          ),
        );
      }
      if (!mounted) return;
      _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر إعادة إرسال الطلب'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<String?> _askForReason() async {
    final controller = TextEditingController();
    String? result;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('سبب الإلغاء'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'اذكر سبب الإلغاء'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تراجع')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              result = controller.text.trim();
              Navigator.pop(ctx);
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    return result;
  }

  // ─── helpers ────────────────────────────────────────────────────────────────

  String _fmtDateTime(String? s) {
    if (s == null || s.isEmpty) return '';
    try {
      final d = DateTime.parse(s).toLocal();
      return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} • '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return s;
    }
  }

  String _fmtDate(String? s) {
    if (s == null || s.isEmpty) return '';
    try {
      final d = DateTime.parse(s).toLocal();
      return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return s;
    }
  }

  (String, MqBadgeTone, IconData) _statusMeta(String s) {
    switch (s.toLowerCase()) {
      case 'pending':
        return ('قيد الانتظار', MqBadgeTone.orange, Icons.schedule_rounded);
      case 'pre_approved':
        return ('موافقة أولية', MqBadgeTone.accent, Icons.task_alt_rounded);
      case 'confirmed':
        return ('تم التأكيد', MqBadgeTone.success, Icons.verified_rounded);
      case 'approved':
        return ('موافق نهائياً', MqBadgeTone.success, Icons.check_circle_rounded);
      case 'rejected':
        return ('مرفوض', MqBadgeTone.error, Icons.cancel_rounded);
      case 'cancelled':
      case 'canceled':
        return ('ملغي', MqBadgeTone.neutral, Icons.block_rounded);
      default:
        return (s, MqBadgeTone.neutral, Icons.help_outline_rounded);
    }
  }

  Color _toneColor(BuildContext context, MqBadgeTone tone) {
    final m = context.mq;
    return switch (tone) {
      MqBadgeTone.orange => m.orange,
      MqBadgeTone.accent => m.accent,
      MqBadgeTone.success => m.success,
      MqBadgeTone.error => m.error,
      MqBadgeTone.neutral => m.ink3,
    };
  }

  String _nextStep(String s) => switch (s.toLowerCase()) {
        'pending' => 'بانتظار مراجعة الأستاذ لطلبك',
        'pre_approved' => 'تمت الموافقة المبدئية — بانتظار التأكيد',
        'confirmed' => 'تم تأكيد حجزك',
        'approved' => 'تم قبولك في الدورة',
        'rejected' => 'تم رفض الطلب',
        'cancelled' || 'canceled' => 'تم إلغاء الطلب',
        _ => '',
      };

  // ─── build ──────────────────────────────────────────────────────────────────

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
            appBar: AppBar(title: const Text('تفاصيل الحجز')),
            body: _loading
                ? _skeleton(context)
                : _error != null
                    ? _errorView(context)
                    : _data == null
                        ? _errorView(context)
                        : RefreshIndicator(onRefresh: _load, child: _content(context, _data!)),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, Map<String, dynamic> b) {
    final status = (b['status'] ?? '').toString();
    final course = b['course'] is Map ? Map<String, dynamic>.from(b['course']) : null;
    final teacher = b['teacher'] is Map ? Map<String, dynamic>.from(b['teacher']) : null;

    final notes = _noteWidgets(context, b);
    final timeline = _timelineRows(context, b);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.lg, MqSpacing.lg, MqSpacing.xxxl),
      children: [
        _statusCard(context, b, status),
        if (course != null) ...[MqSpacing.gapMd, _courseCard(context, course)],
        if (teacher != null) ...[MqSpacing.gapMd, _teacherCard(context, teacher)],
        if (notes.isNotEmpty) ...[MqSpacing.gapMd, _sectionCard(context, 'الملاحظات والتواصل', Icons.message_outlined, notes)],
        if (timeline.isNotEmpty) ...[MqSpacing.gapMd, _sectionCard(context, 'التسلسل الزمني', Icons.timeline_rounded, timeline)],
        MqSpacing.gapMd,
        _actions(context, status, b),
      ],
    );
  }

  Widget _statusCard(BuildContext context, Map<String, dynamic> b, String status) {
    final (label, tone, icon) = _statusMeta(status);
    final color = _toneColor(context, tone);
    final id = (b['id'] ?? '').toString();
    final shortId = id.length > 8 ? id.substring(id.length - 8) : id;
    final date = _fmtDate(b['bookingDate']?.toString() ?? b['createdAt']?.toString());
    final next = _nextStep(status);

    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: MqRadius.brMd),
              child: Icon(icon, color: color, size: MqSize.iconMd),
            ),
            MqSpacing.gapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('حجز #$shortId', style: context.text.titleSmall),
                  if (date.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('تاريخ الطلب: $date', style: context.text.labelSmall),
                  ],
                ],
              ),
            ),
            MqBadge(label: label, tone: tone),
          ]),
          if (next.isNotEmpty) ...[
            MqSpacing.gapSm,
            MqSurface(
              tone: MqSurfaceTone.neutral,
              padding: const EdgeInsets.all(MqSpacing.sm),
              child: Row(children: [
                Icon(Icons.flag_outlined, size: 14, color: color),
                MqSpacing.gapXs,
                Expanded(child: Text(next, style: context.text.bodySmall)),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _courseCard(BuildContext context, Map<String, dynamic> c) {
    final m = context.mq;
    final images = c['courseImages'] as List?;
    final imgPath = (images != null && images.isNotEmpty) ? images.first.toString() : '';
    final imgUrl = imgPath.isEmpty ? '' : (imgPath.startsWith('http') ? imgPath : '${AppConfig.serverBaseUrl}$imgPath');
    final hasReservation = c['hasReservation'] == true || c['hasReservation']?.toString() == 'true';
    final desc = (c['description'] ?? '').toString().trim();
    final start = _fmtDate(c['startDate']?.toString());
    final end = _fmtDate(c['endDate']?.toString());

    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(context, 'معلومات الدورة', Icons.school_outlined),
          MqSpacing.gapSm,
          if (imgUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: MqRadius.brMd,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: AppNetworkImage(url: imgUrl, fit: BoxFit.cover, fallbackIcon: Icons.school_rounded),
              ),
            ),
            MqSpacing.gapSm,
          ],
          Text(c['courseName']?.toString() ?? 'غير محدد', style: context.text.titleSmall),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(desc, style: context.text.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
          MqSpacing.gapSm,
          Wrap(spacing: MqSpacing.xs, runSpacing: MqSpacing.xs, children: [
            if (c['price'] != null) MqBadge(label: '${fmtMoney(c['price'])} د.ع', tone: MqBadgeTone.success, icon: Icons.payments_outlined),
            if (hasReservation && c['reservationAmount'] != null)
              MqBadge(label: 'حجز: ${fmtMoney(c['reservationAmount'])} د.ع', tone: MqBadgeTone.orange, icon: Icons.account_balance_wallet_outlined),
            if (c['seatsCount'] != null) MqBadge(label: '${c['seatsCount']} مقعد', tone: MqBadgeTone.neutral, icon: Icons.event_seat_outlined),
          ]),
          if (start.isNotEmpty || end.isNotEmpty) ...[
            MqSpacing.gapSm,
            Row(children: [
              if (start.isNotEmpty) ...[
                Icon(Icons.play_circle_outline_rounded, size: 13, color: m.ink3),
                MqSpacing.gapXxs,
                Text(start, style: context.text.labelSmall),
              ],
              if (end.isNotEmpty) ...[
                MqSpacing.gapMd,
                Icon(Icons.flag_outlined, size: 13, color: m.ink3),
                MqSpacing.gapXxs,
                Text(end, style: context.text.labelSmall),
              ],
            ]),
          ],
        ],
      ),
    );
  }

  Widget _teacherCard(BuildContext context, Map<String, dynamic> t) {
    final m = context.mq;
    final name = (t['name'] ?? 'غير محدد').toString();
    final email = (t['email'] ?? '').toString();
    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: m.accentSoft, shape: BoxShape.circle),
          child: Icon(Icons.person_rounded, color: m.accent, size: 28),
        ),
        MqSpacing.gapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الأستاذ', style: context.text.labelSmall),
              Text(name, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(email, style: context.text.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ]),
    );
  }

  List<Widget> _noteWidgets(BuildContext context, Map<String, dynamic> b) {
    final out = <Widget>[];
    void add(String title, dynamic value, MqBadgeTone tone, IconData icon) {
      final v = value?.toString().trim() ?? '';
      if (v.isEmpty) return;
      out.add(_noteBox(context, title, v, tone, icon));
    }

    add('رسالة الطالب', b['studentMessage'], MqBadgeTone.accent, Icons.message_outlined);
    add('رد الأستاذ', b['teacherResponse'], MqBadgeTone.success, Icons.reply_rounded);
    add('سبب الرفض', b['rejectionReason'], MqBadgeTone.error, Icons.cancel_outlined);
    add('سبب الإلغاء', b['cancellationReason'], MqBadgeTone.orange, Icons.block_outlined);
    return out;
  }

  Widget _noteBox(BuildContext context, String title, String message, MqBadgeTone tone, IconData icon) {
    final color = _toneColor(context, tone);
    return Padding(
      padding: const EdgeInsets.only(bottom: MqSpacing.sm),
      child: MqSurface(
        tone: MqSurfaceTone.neutral,
        padding: const EdgeInsets.all(MqSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 14, color: color),
              MqSpacing.gapXs,
              Text(title, style: context.text.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 4),
            Text(message, style: context.text.bodySmall),
          ],
        ),
      ),
    );
  }

  List<Widget> _timelineRows(BuildContext context, Map<String, dynamic> b) {
    final rows = <Widget>[];
    void add(IconData icon, String label, dynamic value, {bool dateTime = true}) {
      final raw = value?.toString();
      if (raw == null || raw.isEmpty) return;
      final v = dateTime ? _fmtDateTime(raw) : raw;
      rows.add(_kvRow(context, icon, label, v));
    }

    add(Icons.add_circle_outline_rounded, 'تاريخ الإنشاء', b['createdAt']);
    add(Icons.update_rounded, 'آخر تحديث', b['updatedAt']);
    add(Icons.check_circle_outline_rounded, 'تاريخ الموافقة', b['approvedAt']);
    add(Icons.cancel_outlined, 'تاريخ الرفض', b['rejectedAt']);
    add(Icons.block_outlined, 'تاريخ الإلغاء', b['cancelledAt']);
    add(Icons.restart_alt_rounded, 'تاريخ إعادة التفعيل', b['reactivatedAt']);
    add(Icons.person_outline_rounded, 'أُلغي بواسطة', b['cancelledBy'], dateTime: false);
    return rows;
  }

  Widget _kvRow(BuildContext context, IconData icon, String label, String value) {
    final m = context.mq;
    return Padding(
      padding: const EdgeInsets.only(bottom: MqSpacing.xs),
      child: Row(children: [
        Icon(icon, size: 14, color: m.ink3),
        MqSpacing.gapXs,
        Text('$label: ', style: context.text.labelSmall),
        Expanded(child: Text(value, style: context.text.labelSmall?.copyWith(color: m.ink, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _cardHeader(BuildContext context, String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: MqSize.iconSm, color: context.mq.accent),
      MqSpacing.gapXs,
      Text(title, style: context.text.titleSmall),
    ]);
  }

  Widget _sectionCard(BuildContext context, String title, IconData icon, List<Widget> children) {
    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(context, title, icon),
          MqSpacing.gapSm,
          ...children,
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, String status, Map<String, dynamic> b) {
    final m = context.mq;
    final s = status.toLowerCase();
    final rejectedByTeacher = b['rejectedBy']?.toString().toLowerCase() == 'teacher';
    final canCancel = s == 'pending' || s == 'approved';
    final canReactivate = (s == 'rejected' || s == 'cancelled' || s == 'canceled') && !rejectedByTeacher;

    final buttons = <Widget>[];
    if (canCancel) {
      buttons.add(Expanded(
        child: MqButton(label: 'إلغاء الحجز', icon: Icons.cancel_outlined, variant: MqButtonVariant.secondary, onPressed: _cancel),
      ));
    }
    if (canReactivate) {
      if (buttons.isNotEmpty) buttons.add(MqSpacing.gapSm);
      buttons.add(Expanded(
        child: MqButton(label: 'إعادة الإرسال', icon: Icons.restart_alt_rounded, onPressed: _reactivate),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (buttons.isNotEmpty) Row(children: buttons),
        if (s == 'rejected' && rejectedByTeacher)
          MqSurface(
            tone: MqSurfaceTone.orange,
            padding: const EdgeInsets.all(MqSpacing.sm),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, color: m.orange, size: MqSize.iconSm),
              MqSpacing.gapXs,
              Expanded(child: Text('تم رفض طلبك من قبل الأستاذ. يرجى مراجعته لمعرفة الأسباب.', style: context.text.bodySmall)),
            ]),
          ),
      ],
    );
  }

  // ─── states ─────────────────────────────────────────────────────────────────

  Widget _errorView(BuildContext context) {
    final m = context.mq;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MqSpacing.lg),
      children: [
        const SizedBox(height: MqSpacing.xxxl),
        Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off_rounded, size: 44, color: m.error),
          MqSpacing.gapMd,
          Text(_error ?? 'تعذّر تحميل الحجز', textAlign: TextAlign.center, style: context.text.bodyMedium),
          MqSpacing.gapMd,
          MqButton(label: 'إعادة المحاولة', icon: Icons.refresh_rounded, expand: false, onPressed: _load),
        ])),
      ],
    );
  }

  Widget _skeleton(BuildContext context) {
    final m = context.mq;
    Widget block(double h) => Container(height: h, decoration: BoxDecoration(color: m.fill2, borderRadius: MqRadius.brLg));
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MqSpacing.lg),
      children: [block(96), MqSpacing.gapMd, block(160), MqSpacing.gapMd, block(80), MqSpacing.gapMd, block(110)],
    );
  }
}
