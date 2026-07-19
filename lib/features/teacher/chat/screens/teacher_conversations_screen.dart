import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../../../core/utils/time_format.dart';
import '../../shared/design/teacher_design.dart';
import '../controllers/conversations_controller.dart';
import '../models/chat_models.dart';
import 'teacher_conversation_screen.dart';
import 'teacher_create_group_screen.dart';

/// Teacher conversations list — matched to `Chat_light.html` / `Chat_Dark.html`.
///
/// Header (title + live unread count) → filter chips (real, backed by
/// `peer.userType` + unread) → conversation rows (avatar · name · role badge ·
/// preview · time · unread badge). The "+" create-group action is kept, only
/// restyled to the design system. Filtering is presentation-only; the
/// controller / chat API / socket contract is untouched.
class TeacherConversationsScreen extends StatefulWidget {
  const TeacherConversationsScreen({super.key});

  @override
  State<TeacherConversationsScreen> createState() =>
      _TeacherConversationsScreenState();
}

enum _Filter { all, students, groups, unread }

class _TeacherConversationsScreenState
    extends State<TeacherConversationsScreen> {
  late final ConversationsController _ctrl;
  String? _myUserId;
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(ConversationsController(), tag: 'teacher-conversations');
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final userRaw = prefs.getString('user');
    if (userRaw != null) {
      try {
        final user = jsonDecode(userRaw) as Map<String, dynamic>;
        _myUserId = (user['id'] ?? user['_id'])?.toString();
      } catch (_) {}
    }
    if (_myUserId == null) return;
    await _ctrl.initialize(myUserId: _myUserId!);
  }

  @override
  void dispose() {
    Get.delete<ConversationsController>(tag: 'teacher-conversations');
    super.dispose();
  }

  List<ChatConversation> _applyFilter(List<ChatConversation> all) {
    switch (_filter) {
      case _Filter.all:
        return all;
      case _Filter.students:
        return all
            .where(
              (c) => !c.isGroup && (c.peer?.userType ?? 'student') == 'student',
            )
            .toList();
      case _Filter.groups:
        return all.where((c) => c.isGroup).toList();
      case _Filter.unread:
        return all.where((c) => c.unreadCount > 0).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: isDark ? MqTheme.dark() : MqTheme.light(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) {
            final mq = context.mq;
            return Scaffold(
              backgroundColor: mq.page,
              appBar: _appBar(context),
              body: Obx(() {
                final all = _ctrl.conversations;
                final totalUnread = all.fold<int>(
                  0,
                  (s, c) => s + c.unreadCount,
                );

                if (_ctrl.loading.value && all.isEmpty) {
                  return Center(
                    child: CircularProgressIndicator(color: mq.accent),
                  );
                }
                if (_ctrl.error.value != null && all.isEmpty) {
                  return _ErrorView(
                    message: _ctrl.error.value!,
                    onRetry: _ctrl.fetch,
                  );
                }

                final list = _applyFilter(all);
                return Column(
                  children: [
                    _filters(context, totalUnread),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => _ctrl.fetch(isRefresh: true),
                        color: mq.accent,
                        child: list.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 100),
                                  _EmptyConversations(),
                                ],
                              )
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.only(
                                  bottom: MqSpacing.lg,
                                ),
                                itemCount: list.length,
                                separatorBuilder: (_, _) => Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    start: 72,
                                    end: MqSpacing.lg,
                                  ),
                                  child: Divider(height: 1, color: mq.line),
                                ),
                                itemBuilder: (ctx, i) => _ConversationTile(
                                  conversation: list[i],
                                  onTap: () => _openConversation(list[i]),
                                ),
                              ),
                      ),
                    ),
                  ],
                );
              }),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context) {
    final mq = context.mq;
    return AppBar(
      backgroundColor: mq.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      leadingWidth: 56,
      leading: Navigator.of(context).canPop()
          ? Align(
              child: _ChatChip(
                icon: Icons.arrow_forward_rounded,
                tooltip: 'رجوع',
                onTap: () => Navigator.of(context).maybePop(),
              ),
            )
          : null,
      title: Obx(() {
        final unread = _ctrl.conversations.fold<int>(
          0,
          (s, c) => s + c.unreadCount,
        );
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'المحادثات',
              style: context.text.titleMedium?.copyWith(color: mq.ink),
            ),
            Text(
              unread > 0 ? '$unread رسائل غير مقروءة' : 'كل الرسائل مقروءة',
              style: context.text.labelSmall?.copyWith(
                color: unread > 0 ? mq.accent : mq.ink3,
              ),
            ),
          ],
        );
      }),
      actions: [
        _ChatChip(
          icon: Icons.group_add_outlined,
          tooltip: 'مجموعة جديدة',
          accent: true,
          onTap: _openCreateGroup,
        ),
        const SizedBox(width: MqSpacing.lg),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: mq.line),
      ),
    );
  }

  Widget _filters(BuildContext context, int totalUnread) {
    final items = <(_Filter, String)>[
      (_Filter.all, 'الكل'),
      (_Filter.students, 'الطلاب'),
      (_Filter.groups, 'المجموعات'),
      (_Filter.unread, 'غير مقروء${totalUnread > 0 ? ' ($totalUnread)' : ''}'),
    ];
    return Container(
      color: context.mq.card,
      padding: const EdgeInsets.fromLTRB(
        MqSpacing.lg,
        MqSpacing.sm,
        MqSpacing.lg,
        MqSpacing.md,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (f, label) in items) ...[
              MqChip(
                label: label,
                selected: _filter == f,
                onTap: () => setState(() => _filter = f),
              ),
              const SizedBox(width: MqSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openConversation(ChatConversation c) async {
    if (_myUserId == null) return;
    _ctrl.markConversationOpened(c.id);
    await Get.to(
      () => TeacherConversationScreen(
        conversationId: c.id,
        initialTitle: c.displayName(),
        myUserId: _myUserId!,
      ),
    );
  }

  Future<void> _openCreateGroup() async {
    final created = await Get.to<bool>(() => const TeacherCreateGroupScreen());
    if (created == true) {
      await _ctrl.fetch(isRefresh: true);
    }
  }
}

// ---------------------------------------------------------------------------
//  Header chip (back / add)
// ---------------------------------------------------------------------------

class _ChatChip extends StatelessWidget {
  const _ChatChip({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final fg = accent ? mq.accent : mq.ink2;
    final bg = accent ? mq.accentSoft : mq.fill;
    final border = accent ? mq.accentLine : mq.line;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: MqRadius.brMd,
          side: BorderSide(color: border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: MqSize.iconSm, color: fg),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Conversation tile
// ---------------------------------------------------------------------------

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.onTap});
  final ChatConversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final c = conversation;
    final unread = c.unreadCount > 0;
    final timeStr = c.lastMessageAt != null
        ? _relativeTime(c.lastMessageAt!)
        : '';
    final (roleLabel, roleTone) = _role(c);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MqSpacing.lg,
          vertical: MqSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(name: c.displayName(), isGroup: c.isGroup),
            const SizedBox(width: MqSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          c.displayName(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodyMedium?.copyWith(
                            color: mq.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: MqSpacing.sm),
                      MqBadge(label: roleLabel, tone: roleTone),
                      if (c.mode == ConversationMode.announceOnly) ...[
                        const SizedBox(width: MqSpacing.xs),
                        Icon(Icons.campaign_outlined, size: 14, color: mq.ink3),
                      ],
                      const Spacer(),
                      Text(
                        timeStr,
                        style: context.text.labelSmall?.copyWith(
                          color: unread ? mq.accent : mq.ink3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _preview(c),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(
                            color: unread ? mq.ink : mq.ink2,
                            fontWeight: unread
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (unread) ...[
                        const SizedBox(width: MqSpacing.sm),
                        _UnreadBadge(count: c.unreadCount),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (String, MqBadgeTone) _role(ChatConversation c) {
    if (c.isGroup) return ('مجموعة', MqBadgeTone.orange);
    switch (c.peer?.userType) {
      case 'teacher':
        return ('معلّم', MqBadgeTone.success);
      case 'super_admin':
        return ('إدارة', MqBadgeTone.neutral);
      default:
        return ('طالب', MqBadgeTone.accent);
    }
  }

  String _preview(ChatConversation c) {
    final m = c.lastMessage;
    if (m == null) return c.isGroup ? 'لا توجد رسائل بعد' : 'ابدأ المحادثة';
    if (m.isDeleted) return 'تم حذف هذه الرسالة';
    if ((m.body ?? '').trim().isNotEmpty) return m.body!.trim();
    if (m.kind == MessageKind.image) return '📷 صورة';
    if (m.kind == MessageKind.file) return '📎 ملف';
    return '';
  }

  String _relativeTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inHours < 1) return '${diff.inMinutes} د';
    if (diff.inDays < 1) return formatTime12(t);
    if (diff.inDays < 7) return DateFormat('EEEE', 'ar').format(t);
    return DateFormat('dd/MM').format(t);
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.isGroup});
  final String name;
  final bool isGroup;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final initials = name.isNotEmpty ? name.characters.first : '؟';
    final bg = isGroup ? mq.orangeSoft : mq.accentSoft;
    final fg = isGroup ? mq.orangeDeep : mq.accent;
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: isGroup ? mq.orangeLine : mq.accentLine),
      ),
      alignment: Alignment.center,
      child: isGroup
          ? Icon(Icons.groups_2_outlined, color: fg, size: 22)
          : Text(
              initials,
              style: MqTypography.mono(
                color: fg,
                size: 18,
                weight: FontWeight.w700,
              ),
            ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: mq.accent,
        borderRadius: MqRadius.brPill,
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyConversations extends StatelessWidget {
  const _EmptyConversations();
  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MqSpacing.xl),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: mq.accentSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.forum_outlined, size: 34, color: mq.accent),
          ),
          const SizedBox(height: MqSpacing.md),
          Text('لا توجد محادثات بعد', style: context.text.titleSmall),
          const SizedBox(height: MqSpacing.xs),
          Text(
            'أنشئ مجموعة جديدة أو ابدأ محادثة خاصة مع طالب',
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(color: mq.ink2),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MqSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: mq.error),
            const SizedBox(height: MqSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium,
            ),
            const SizedBox(height: MqSpacing.lg),
            MqButton(
              label: 'إعادة المحاولة',
              icon: Icons.refresh_rounded,
              expand: false,
              onPressed: () => onRetry(),
            ),
          ],
        ),
      ),
    );
  }
}
