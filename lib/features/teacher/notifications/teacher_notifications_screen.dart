import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/teacher_api_service.dart';
import '../shared/design/teacher_design.dart';
import '../shared/teacher_app_bar.dart';
import '../shared/teacher_drawer.dart';
import '../shared/teacher_helpers.dart' show fmtRelative;
import '../shared/teacher_workspace.dart';

/// Teacher → "الإشعارات" (Teacher Design System pass).
///
/// Two sources, toggled by the مستلمة / مرسلة filter:
///   • مستلمة (received) — notifications the super-admin / system sent TO the
///     teacher (`/notifications/user/my-notifications`). Tap → mark read.
///   • مرسلة (sent)     — notifications the teacher sent to students
///     (`/teacher/notifications`). Compose (FAB) + delete.
///
/// Presentation only — `fetchMyNotifications`, `markNotificationAsRead`,
/// `fetchNotifications`, `createNotification`, `deleteNotification` unchanged.
class TeacherNotificationsScreen extends StatefulWidget {
  const TeacherNotificationsScreen({super.key});
  @override
  State<TeacherNotificationsScreen> createState() =>
      _TeacherNotificationsScreenState();
}

enum _Box { received, sent }

class _TeacherNotificationsScreenState
    extends State<TeacherNotificationsScreen> {
  final _teacherApi = TeacherApiService();
  final _api = ApiService();

  _Box _box = _Box.received;
  bool _loading = false;
  List<Map<String, dynamic>> _items = [];
  String? _subType;
  String _search = '';
  final _searchCtl = TextEditingController();

  static const _subTypes = <(String?, String)>[
    (null, 'الكل'),
    ('homework', 'واجب'),
    ('message', 'رسالة'),
    ('report', 'تقرير'),
    ('notice', 'تبليغ'),
    ('installments', 'أقساط'),
    ('attendance', 'حضور'),
    ('daily_summary', 'ملخص يومي'),
  ];

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
      if (_box == _Box.received) {
        final res = await _api.fetchMyNotifications(type: _subType, page: 1, limit: 100);
        final list = (res['items'] ?? res['notifications'] ?? res['data'] ?? [])
            as List;
        _items = list
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      } else {
        final res = await _teacherApi.fetchNotifications(
            subType: _subType,
            q: _search.trim().isEmpty ? null : _search.trim(),
            page: 1,
            limit: 100);
        final list = res['data'];
        _items = (list is List)
            ? list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
            : [];
      }
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّر جلب الإشعارات',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _visible {
    // The received endpoint has no server-side text search; filter locally.
    if (_box == _Box.received && _search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      return _items.where((n) {
        final t = (n['title'] ?? '').toString().toLowerCase();
        final m = (n['message'] ?? '').toString().toLowerCase();
        return t.contains(q) || m.contains(q);
      }).toList();
    }
    return _items;
  }

  bool _isUnread(Map n) =>
      !(n['isRead'] == true || n['readAt'] != null || n['status'] == 'read');

  Future<void> _markRead(Map<String, dynamic> n) async {
    if (!_isUnread(n)) return;
    final id = n['id']?.toString();
    if (id == null) return;
    setState(() => n['isRead'] = true);
    try {
      await _api.markNotificationAsRead(id);
    } catch (_) {}
  }

  /// Tap on a received notification: mark it read, then route by type.
  /// A booking-request notification (`new_booking` / any `booking*` type)
  /// takes the teacher straight to the bookings screen.
  void _openReceived(Map<String, dynamic> n) {
    _markRead(n);
    final data = (n['data'] is Map) ? Map<String, dynamic>.from(n['data']) : const {};
    final type = (n['type'] ?? n['notificationType'] ?? n['notification_type'] ?? data['type'])
        ?.toString()
        .toLowerCase() ??
        '';
    if (type.contains('booking')) {
      TeacherWorkspace.jumpTo(context, TeacherWorkspaceState.bookingsIdx);
    }
  }

  Future<void> _delete(Map<String, dynamic> n) async {
    final id = n['id']?.toString();
    if (id == null) return;
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('تأكيد الحذف'),
              content: const Text('سيتم حذف هذا الإشعار.'),
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
      await _teacherApi.deleteNotification(id);
      Get.snackbar('تم', 'تم الحذف', snackPosition: SnackPosition.BOTTOM);
      await _fetch();
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّر الحذف', snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _openComposer() async {
    final titleCtl = TextEditingController();
    final msgCtl = TextEditingController();
    String? subType;
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

            Future<void> send() async {
              if (titleCtl.text.trim().isEmpty || msgCtl.text.trim().isEmpty) {
                Get.snackbar('تنبيه', 'العنوان والرسالة مطلوبان',
                    snackPosition: SnackPosition.BOTTOM);
                return;
              }
              setLocal(() => saving = true);
              try {
                final payload = <String, dynamic>{
                  'type': 'teacher_message',
                  'title': titleCtl.text.trim(),
                  'message': msgCtl.text.trim(),
                  'recipients': {'mode': 'all_students_of_teacher'},
                  'attachments': {},
                  'priority': 'medium',
                };
                if (subType != null) payload['subType'] = subType;
                await _teacherApi.createNotification(payload);
                if (sheetCtx.mounted) Navigator.pop(sheetCtx, true);
              } catch (e) {
                setLocal(() => saving = false);
                Get.snackbar('خطأ', e.toString(),
                    snackPosition: SnackPosition.BOTTOM);
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
                  child: SingleChildScrollView(
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
                              child: Icon(Icons.campaign_outlined,
                                  size: MqSize.iconSm, color: mq.accent),
                            ),
                            const SizedBox(width: MqSpacing.sm),
                            Expanded(
                              child: Text('إرسال إشعار جديد',
                                  style: sheetCtx.text.titleMedium),
                            ),
                            InkWell(
                              onTap: () => Navigator.pop(sheetCtx, false),
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
                        TextField(
                          controller: titleCtl,
                          decoration: const InputDecoration(
                            labelText: 'العنوان *',
                            prefixIcon: Icon(Icons.title_rounded),
                          ),
                        ),
                        const SizedBox(height: MqSpacing.md),
                        TextField(
                          controller: msgCtl,
                          maxLines: 4,
                          decoration: const InputDecoration(
                              labelText: 'نص الرسالة *'),
                        ),
                        const SizedBox(height: MqSpacing.md),
                        DropdownButtonFormField<String>(
                          initialValue: subType,
                          dropdownColor: mq.card,
                          decoration: const InputDecoration(
                            labelText: 'النوع',
                            prefixIcon: Icon(Icons.label_outline_rounded),
                          ),
                          items: [
                            for (final (value, label) in _subTypes)
                              if (value != null)
                                DropdownMenuItem(value: value, child: Text(label))
                          ],
                          onChanged: (v) => setLocal(() => subType = v),
                        ),
                        const SizedBox(height: MqSpacing.md),
                        MqSurface(
                          tone: MqSurfaceTone.neutral,
                          child: Row(
                            children: [
                              Icon(Icons.groups_2_outlined,
                                  size: 18, color: mq.ink3),
                              const SizedBox(width: MqSpacing.sm),
                              Text('المستلمون: كل طلابي',
                                  style: sheetCtx.text.bodySmall
                                      ?.copyWith(color: mq.ink2)),
                            ],
                          ),
                        ),
                        const SizedBox(height: MqSpacing.xl),
                        MqButton(
                          label: saving ? 'جارٍ الإرسال…' : 'إرسال الإشعار',
                          icon: saving ? null : Icons.send_rounded,
                          loading: saving,
                          onPressed: saving ? null : send,
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

    // Dispose after the sheet's slide-out animation; disposing while the
    // TextFields are still rebuilding crashes with "ChangeNotifier used after
    // dispose" (the red `_dependents.isEmpty` screen).
    Future.delayed(const Duration(milliseconds: 500), () {
      titleCtl.dispose();
      msgCtl.dispose();
    });
    if (ok == true) {
      Get.snackbar('تم', 'تم إرسال الإشعار',
          snackPosition: SnackPosition.BOTTOM);
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
          return Scaffold(
            backgroundColor: mq.page,
            appBar: TeacherAppBar(
              title: 'الإشعارات',
              actions: [_RefreshAction(loading: _loading, onTap: _fetch)],
            ),
            drawer: const TeacherDrawer(),
            floatingActionButton: _box == _Box.sent
                ? FloatingActionButton(
                    onPressed: _openComposer,
                    backgroundColor: mq.accent,
                    foregroundColor: mq.onAccent,
                    elevation: 3,
                    tooltip: 'إشعار جديد',
                    shape: const RoundedRectangleBorder(
                        borderRadius: MqRadius.brLg),
                    child: const Icon(Icons.send_rounded),
                  )
                : null,
            body: RefreshIndicator(
              onRefresh: _fetch,
              color: mq.accent,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    MqSpacing.lg, MqSpacing.lg, MqSpacing.lg, 96),
                children: [
                  _hero(context),
                  const SizedBox(height: MqSpacing.lg),
                  _boxToggle(context),
                  const SizedBox(height: MqSpacing.md),
                  _subTypeRow(context),
                  const SizedBox(height: MqSpacing.md),
                  _searchField(context),
                  const SizedBox(height: MqSpacing.lg),
                  if (_loading && _items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(MqSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (visible.isEmpty)
                    _EmptyState(received: _box == _Box.received)
                  else
                    ...visible.map((n) => Padding(
                          padding: const EdgeInsets.only(bottom: MqSpacing.md),
                          child: _box == _Box.received
                              ? _ReceivedCard(
                                  notif: n,
                                  unread: _isUnread(n),
                                  onTap: () => _openReceived(n),
                                )
                              : _SentCard(
                                  notif: n,
                                  onDelete: () => _delete(n),
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
            child: const Icon(Icons.notifications_outlined,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: MqSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الإشعارات',
                    style: context.text.titleMedium?.copyWith(color: t.heroInk)),
                const SizedBox(height: 2),
                Text(
                    _box == _Box.received
                        ? 'إشعارات النظام والإدارة إليك'
                        : 'إشعاراتك المرسلة إلى الطلاب',
                    style:
                        context.text.labelSmall?.copyWith(color: t.heroInk2)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _boxToggle(BuildContext context) {
    final mq = context.mq;
    Widget seg(_Box box, String label, IconData icon) {
      final selected = _box == box;
      return Expanded(
        child: InkWell(
          borderRadius: MqRadius.brMd,
          onTap: () {
            if (_box == box) return;
            setState(() => _box = box);
            _fetch();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: MqSpacing.sm),
            decoration: BoxDecoration(
              color: selected ? mq.accent : Colors.transparent,
              borderRadius: MqRadius.brMd,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 16, color: selected ? mq.onAccent : mq.ink2),
                const SizedBox(width: MqSpacing.xs),
                Text(label,
                    style: context.text.labelMedium?.copyWith(
                        color: selected ? mq.onAccent : mq.ink2,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: mq.fill,
        borderRadius: MqRadius.brMd,
        border: Border.all(color: mq.line),
      ),
      child: Row(
        children: [
          seg(_Box.received, 'مستلمة', Icons.inbox_outlined),
          seg(_Box.sent, 'مرسلة', Icons.outbox_outlined),
        ],
      ),
    );
  }

  Widget _subTypeRow(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (value, label) in _subTypes) ...[
            MqChip(
              label: label,
              selected: _subType == value,
              onTap: () {
                setState(() => _subType = value);
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
        hintText: 'بحث في العنوان أو الرسالة...',
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

class _ReceivedCard extends StatelessWidget {
  const _ReceivedCard(
      {required this.notif, required this.unread, required this.onTap});
  final Map<String, dynamic> notif;
  final bool unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final title = (notif['title'] ?? 'إشعار').toString();
    final message = (notif['message'] ?? '').toString();
    final when = notif['createdAt'] ?? notif['created_at'] ?? notif['sent_at'];

    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: unread ? mq.accentSoft : mq.fill2,
              borderRadius: MqRadius.brMd,
              border: Border.all(color: unread ? mq.accentLine : mq.line),
            ),
            child: Icon(Icons.notifications_active_outlined,
                size: 20, color: unread ? mq.accent : mq.ink3),
          ),
          const SizedBox(width: MqSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodyMedium?.copyWith(
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w600)),
                    ),
                    if (unread)
                      Container(
                        width: 8,
                        height: 8,
                        margin:
                            const EdgeInsets.only(right: MqSpacing.xs, top: 4),
                        decoration:
                            BoxDecoration(color: mq.accent, shape: BoxShape.circle),
                      ),
                  ],
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(color: mq.ink2)),
                ],
                const SizedBox(height: MqSpacing.xs),
                Text(fmtRelative(when),
                    style: context.text.labelSmall?.copyWith(color: mq.ink3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SentCard extends StatelessWidget {
  const _SentCard({required this.notif, required this.onDelete});
  final Map<String, dynamic> notif;
  final VoidCallback onDelete;

  String _modeLabel(String m) {
    switch (m) {
      case 'all_students_of_teacher':
        return 'كل طلابي';
      case 'students_of_course':
        return 'طلاب الكورس';
      case 'students_of_session':
        return 'طلاب الجلسة';
      case 'specific_students':
        return 'طلاب محددون';
      case 'all':
        return 'الكل';
      default:
        return m;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final n = notif;
    final data = (n['data'] is Map) ? Map<String, dynamic>.from(n['data']) : {};
    final recipients =
        (data['recipients'] is Map) ? Map<String, dynamic>.from(data['recipients']) : {};
    final mode = (recipients['mode'] ?? n['recipient_type'] ?? '').toString();
    final count = recipients['studentCount'];
    final message = (n['message'] ?? '').toString();

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
                  color: mq.accentSoft,
                  borderRadius: MqRadius.brMd,
                  border: Border.all(color: mq.accentLine),
                ),
                child: Icon(Icons.outbox_outlined, size: 20, color: mq.accent),
              ),
              const SizedBox(width: MqSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((n['title'] ?? '—').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(fmtRelative(n['sent_at'] ?? n['created_at']),
                        style:
                            context.text.labelSmall?.copyWith(color: mq.ink3)),
                  ],
                ),
              ),
              InkWell(
                onTap: onDelete,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(MqSpacing.xs),
                  child: Icon(Icons.delete_outline_rounded,
                      size: 18, color: mq.error),
                ),
              ),
            ],
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: MqSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(MqSpacing.sm),
              decoration: BoxDecoration(
                color: mq.fill,
                borderRadius: MqRadius.brMd,
                border: BorderDirectional(
                    start: BorderSide(color: mq.accent, width: 3)),
              ),
              child: Text(message,
                  style: context.text.bodySmall?.copyWith(color: mq.ink)),
            ),
          ],
          if (mode.isNotEmpty) ...[
            const SizedBox(height: MqSpacing.sm),
            Wrap(
              spacing: MqSpacing.xs,
              runSpacing: MqSpacing.xs,
              children: [
                MqBadge(label: _modeLabel(mode), tone: MqBadgeTone.accent),
                if (count != null)
                  MqBadge(label: '$count طالب', tone: MqBadgeTone.neutral),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.received});
  final bool received;
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
            child: Icon(
                received ? Icons.inbox_outlined : Icons.outbox_outlined,
                size: 34,
                color: mq.ink3),
          ),
          const SizedBox(height: MqSpacing.md),
          Text(
            received
                ? 'لا توجد إشعارات مستلمة'
                : 'لم ترسل أي إشعار بعد',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: mq.ink2),
          ),
          if (!received) ...[
            const SizedBox(height: MqSpacing.xs),
            Text('أرسل إشعاراً لطلابك من زر «إشعار جديد»',
                textAlign: TextAlign.center,
                style: context.text.bodySmall?.copyWith(color: mq.ink3)),
          ],
        ],
      ),
    );
  }
}
