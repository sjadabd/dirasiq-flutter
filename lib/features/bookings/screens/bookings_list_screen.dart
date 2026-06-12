// Student → My bookings (MulhimIQ design-system pass). RootShell tab
// "حجوزاتي" + standalone route /bookings.
//
// Backed by ApiService.fetchStudentBookings → GET /student/bookings (status +
// study-year + pagination, all server-side). The status set, server filter,
// pagination, and navigation to /booking-details are UNCHANGED. The original
// list had a "cancel" button on pending whose confirm dialog did nothing
// (no API call); it is now wired to the existing ApiService.cancelBooking —
// the same endpoint the details screen already uses — so the action actually
// works. No payment / course-hub actions are added (none exist in the booking
// flow → "never invent").

import 'package:flutter/material.dart';

import 'package:mulhimiq/core/config/app_config.dart';
import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';
import 'package:mulhimiq/shared/widgets/app_network_image.dart';

/// Money with thousands separators and no decimals (e.g. 100000.00 → 100,000).
String _fmtMoney(dynamic v) {
  final n = num.tryParse((v ?? '').toString());
  if (n == null) return '';
  return n
      .round()
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
}

class BookingsListScreen extends StatefulWidget {
  final void Function(int index)? onNavigateToTab;
  const BookingsListScreen({super.key, this.onNavigateToTab});

  @override
  State<BookingsListScreen> createState() => _BookingsListScreenState();
}

class _BookingsListScreenState extends State<BookingsListScreen> {
  final _api = ApiService();

  String? _statusFilter;
  String? _studyYear;
  int _page = 1;
  final int _limit = 10;
  bool _loading = false;
  bool _hasMore = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  // Server-supported status values (preserves the original filter behaviour).
  static const List<(String?, String)> _statusChips = [
    (null, 'الكل'),
    ('pending', 'قيد الانتظار'),
    ('pre_approved', 'موافقة أولية'),
    ('confirmed', 'تم التأكيد'),
    ('rejected', 'مرفوض'),
    ('cancelled', 'ملغي'),
  ];

  @override
  void initState() {
    super.initState();
    _studyYear ??= DateTime.now().month >= 9
        ? '${DateTime.now().year}-${DateTime.now().year + 1}'
        : '${DateTime.now().year - 1}-${DateTime.now().year}';
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _page = 1;
      _items = [];
      _hasMore = true;
      _error = null;
    });
    await _fetchPage(reset: true);
  }

  Future<void> _fetchPage({bool reset = false}) async {
    if (_loading || (!_hasMore && !reset)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.fetchStudentBookings(
        studyYear: _studyYear,
        page: _page,
        limit: _limit,
        status: _statusFilter,
      );
      List<dynamic> list = [];
      if (res['data'] is List) {
        list = res['data'] as List;
      } else if (res['data'] is Map) {
        final data = res['data'] as Map<String, dynamic>;
        list = (data['items'] ?? data['data'] ?? []) as List;
      }
      final items = List<Map<String, dynamic>>.from(list);
      setState(() {
        if (_page == 1) {
          _items = items;
        } else {
          _items.addAll(items);
        }
        _hasMore = items.length >= _limit;
        if (_hasMore) _page++;
      });
    } catch (_) {
      setState(() => _error = 'تعذّر تحميل الحجوزات');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onFilter(String? value) {
    if (_statusFilter == value) return;
    setState(() {
      _statusFilter = value;
      _page = 1;
      _items = [];
      _hasMore = true;
    });
    _fetchPage(reset: true);
  }

  // ─── cancel (wired to the existing endpoint) ────────────────────────────────

  Future<void> _cancel(String? id) async {
    if (id == null || id.isEmpty) return;
    final reason = await _askReason();
    if (reason == null) return;
    try {
      await _api.cancelBooking(bookingId: id, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء الحجز'), behavior: SnackBarBehavior.floating),
      );
      _loadInitial();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر إلغاء الحجز'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<String?> _askReason() async {
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
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );
    return result;
  }

  // ─── status helpers ─────────────────────────────────────────────────────────

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

  String _fmtDate(String? s) {
    if (s == null || s.isEmpty) return '';
    try {
      final d = DateTime.parse(s).toLocal();
      return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return s;
    }
  }

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
            appBar: AppBar(
              automaticallyImplyLeading: Navigator.of(context).canPop(),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('حجوزاتي'),
                  Text('تابع حالة طلبات التسجيل الخاصة بك', style: context.text.bodySmall),
                ],
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: _filters(context),
              ),
            ),
            body: RefreshIndicator(onRefresh: _loadInitial, child: _body(context)),
          ),
        ),
      ),
    );
  }

  Widget _filters(BuildContext context) {
    return SizedBox(
      height: MqSize.chipHeight + MqSpacing.sm,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(MqSpacing.lg, 0, MqSpacing.lg, MqSpacing.sm),
        itemCount: _statusChips.length,
        separatorBuilder: (_, _) => const SizedBox(width: MqSpacing.xs),
        itemBuilder: (_, i) {
          final (value, label) = _statusChips[i];
          return MqChip(label: label, selected: _statusFilter == value, onTap: () => _onFilter(value));
        },
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading && _items.isEmpty) return _skeleton(context);
    if (_error != null && _items.isEmpty) return _errorView(context);
    if (_items.isEmpty) return _empty(context);

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.md, MqSpacing.lg, MqSpacing.xxxl + MqSpacing.xl),
      itemCount: _items.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: MqSpacing.sm),
      itemBuilder: (context, index) {
        if (index < _items.length) return _bookingCard(context, _items[index]);
        // footer: load-more / spinner
        if (_loading) {
          return const Padding(
            padding: EdgeInsets.all(MqSpacing.md),
            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        if (_hasMore) {
          return Center(
            child: MqButton.text(label: 'تحميل المزيد', icon: Icons.expand_more_rounded, onPressed: _fetchPage),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _bookingCard(BuildContext context, Map<String, dynamic> b) {
    final m = context.mq;
    final status = (b['status'] ?? '').toString();
    final (label, tone, icon) = _statusMeta(status);
    final color = _toneColor(context, tone);
    final courseName = (b['courseName'] ?? 'دورة غير محددة').toString();
    final teacherName = (b['teacher_name'] ?? '').toString();
    final price = _fmtMoney(b['price']);
    final bookingDate = _fmtDate(b['bookingDate']?.toString());
    final note = (b['studentMessage'] ?? '').toString().trim();
    final id = b['id']?.toString();
    final imgs = b['courseImages'];
    final imgPath = (imgs is List && imgs.isNotEmpty) ? imgs.first.toString() : '';
    final imgUrl = imgPath.isEmpty ? '' : (imgPath.startsWith('http') ? imgPath : '${AppConfig.serverBaseUrl}$imgPath');
    final nextStep = _nextStep(status);

    return MqCard(
      padding: EdgeInsets.zero,
      onTap: id == null ? null : () => Navigator.pushNamed(context, '/booking-details', arguments: id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (imgUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: AppNetworkImage(url: imgUrl, fit: BoxFit.cover, fallbackIcon: Icons.school_rounded),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(MqSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: MqRadius.brMd),
                      child: Icon(icon, color: color, size: MqSize.iconSm),
                    ),
                    MqSpacing.gapSm,
                    Expanded(
                      child: Text(courseName, style: context.text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                    MqSpacing.gapSm,
                    MqBadge(label: label, tone: tone),
                  ],
                ),
                MqSpacing.gapSm,
                Row(children: [
                  if (teacherName.isNotEmpty) ...[
                    Icon(Icons.person_outline_rounded, size: 13, color: m.ink3),
                    MqSpacing.gapXxs,
                    Expanded(child: Text(teacherName, style: context.text.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ] else
                    const Spacer(),
                  if (bookingDate.isNotEmpty) ...[
                    Icon(Icons.event_outlined, size: 13, color: m.ink3),
                    MqSpacing.gapXxs,
                    Text(bookingDate, style: context.text.labelSmall),
                  ],
                ]),
                if (price.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.payments_outlined, size: 13, color: m.ink3),
                    MqSpacing.gapXxs,
                    Text('$price د.ع', style: context.text.labelSmall),
                  ]),
                ],
                if (nextStep.isNotEmpty) ...[
                  MqSpacing.gapSm,
                  MqSurface(
                    tone: MqSurfaceTone.neutral,
                    padding: const EdgeInsets.symmetric(horizontal: MqSpacing.sm, vertical: MqSpacing.xs),
                    child: Row(children: [
                      Icon(Icons.flag_outlined, size: 13, color: color),
                      MqSpacing.gapXs,
                      Expanded(child: Text(nextStep, style: context.text.labelSmall)),
                    ]),
                  ),
                ],
                if (note.isNotEmpty) ...[
                  MqSpacing.gapSm,
                  MqSurface(
                    tone: MqSurfaceTone.neutral,
                    padding: const EdgeInsets.symmetric(horizontal: MqSpacing.sm, vertical: MqSpacing.xs),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.message_outlined, size: 13, color: m.ink3),
                      MqSpacing.gapXs,
                      Expanded(child: Text(note, style: context.text.labelSmall, maxLines: 2, overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
                ],
                MqSpacing.gapSm,
                Row(children: [
                  Expanded(
                    child: MqButton(
                      label: 'عرض التفاصيل',
                      icon: Icons.visibility_outlined,
                      size: MqButtonSize.small,
                      variant: MqButtonVariant.tonal,
                      onPressed: id == null ? null : () => Navigator.pushNamed(context, '/booking-details', arguments: id),
                    ),
                  ),
                  if (status == 'pending') ...[
                    MqSpacing.gapSm,
                    Expanded(
                      child: MqButton(
                        label: 'إلغاء الطلب',
                        icon: Icons.cancel_outlined,
                        size: MqButtonSize.small,
                        variant: MqButtonVariant.secondary,
                        onPressed: () => _cancel(id),
                      ),
                    ),
                  ],
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── states ─────────────────────────────────────────────────────────────────

  Widget _empty(BuildContext context) {
    final m = context.mq;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MqSpacing.lg),
      children: [
        const SizedBox(height: MqSpacing.xxl),
        Center(child: Column(children: [
          Container(
            padding: const EdgeInsets.all(MqSpacing.lg),
            decoration: BoxDecoration(color: m.accentSoft, shape: BoxShape.circle),
            child: Icon(Icons.inbox_rounded, size: 44, color: m.accent),
          ),
          MqSpacing.gapMd,
          Text('لا توجد حجوزات', style: context.text.titleMedium),
          MqSpacing.gapXs,
          Text('ستظهر هنا طلبات التسجيل في الدورات.', textAlign: TextAlign.center, style: context.text.bodySmall),
          if (widget.onNavigateToTab != null) ...[
            MqSpacing.gapLg,
            MqButton(
              label: 'تصفّح الدورات',
              icon: Icons.search_rounded,
              expand: false,
              onPressed: () => widget.onNavigateToTab?.call(1),
            ),
          ],
        ])),
      ],
    );
  }

  Widget _errorView(BuildContext context) {
    final m = context.mq;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MqSpacing.lg),
      children: [
        const SizedBox(height: MqSpacing.xxl),
        Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off_rounded, size: 44, color: m.error),
          MqSpacing.gapMd,
          Text(_error ?? 'حدث خطأ', textAlign: TextAlign.center, style: context.text.bodyMedium),
          MqSpacing.gapMd,
          MqButton(label: 'إعادة المحاولة', icon: Icons.refresh_rounded, expand: false, onPressed: _loadInitial),
        ])),
      ],
    );
  }

  Widget _skeleton(BuildContext context) {
    final m = context.mq;
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.md, MqSpacing.lg, MqSpacing.lg),
      children: [
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: MqSpacing.sm),
            child: MqCard(
              padding: const EdgeInsets.all(MqSpacing.md),
              child: Row(children: [
                Container(width: 36, height: 36, decoration: BoxDecoration(color: m.fill2, borderRadius: MqRadius.brMd)),
                MqSpacing.gapMd,
                Expanded(child: Container(height: 40, decoration: BoxDecoration(color: m.fill2, borderRadius: MqRadius.brSm))),
              ]),
            ),
          ),
      ],
    );
  }
}
