// Student-side conversations list — Phase 7 (MulhimIQ design-system pass).
//
// Reuses the role-agnostic ConversationsController + ChatSocketService from
// the shared `teacher/chat/...` module (the folder name is historical — the
// services / models / controllers themselves are role-neutral).
//
// This pass restyles the UI with the MulhimIQ design system (MqCard, MqBadge,
// tokens) to match Student Home. All controller / socket / unread logic is
// untouched: initialize → fetch → markConversationOpened on tap, unread via
// ChatUnreadService through the controller.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/app_config.dart';
import '../../../teacher/chat/controllers/conversations_controller.dart';
import '../../../teacher/chat/models/chat_models.dart';
import '../../../teacher/chat/services/chat_socket_service.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';
import 'student_conversation_screen.dart';

class StudentConversationsScreen extends StatefulWidget {
  const StudentConversationsScreen({super.key});

  @override
  State<StudentConversationsScreen> createState() =>
      _StudentConversationsScreenState();
}

class _StudentConversationsScreenState
    extends State<StudentConversationsScreen> {
  late final ConversationsController _ctrl;
  String? _myUserId;
  final _search = TextEditingController();
  final _query = ''.obs;

  @override
  void initState() {
    super.initState();
    // Distinct GetX tag so this controller never collides with the teacher
    // instance — important when role-switching during the same session.
    _ctrl = Get.put(ConversationsController(), tag: 'student-conversations');
    _search.addListener(() => _query.value = _search.text.trim());
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
    if (_myUserId == null || _myUserId!.isEmpty) return;
    await _ctrl.initialize(myUserId: _myUserId!);
  }

  @override
  void dispose() {
    _search.dispose();
    Get.delete<ConversationsController>(tag: 'student-conversations');
    super.dispose();
  }

  List<ChatConversation> _filtered(List<ChatConversation> all) {
    final q = _query.value.toLowerCase();
    if (q.isEmpty) return all;
    return all.where((c) {
      final name = c.displayName().toLowerCase();
      final preview = _preview(c).toLowerCase();
      return name.contains(q) || preview.contains(q);
    }).toList();
  }

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
            appBar: AppBar(title: const Text('الدردشة')),
            body: Column(
              children: [
                const ChatConnectionBanner(),
                _searchBar(context),
                Expanded(
                  child: Obx(() {
                    if (_ctrl.loading.value && _ctrl.conversations.isEmpty) {
                      return _Skeleton();
                    }
                    if (_ctrl.error.value != null && _ctrl.conversations.isEmpty) {
                      return _ErrorView(message: _ctrl.error.value!, onRetry: _ctrl.fetch);
                    }
                    final items = _filtered(_ctrl.conversations);
                    return RefreshIndicator(
                      onRefresh: () => _ctrl.fetch(isRefresh: true),
                      child: _ctrl.conversations.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: const [SizedBox(height: 100), _EmptyConversations()],
                            )
                          : items.isEmpty
                              ? ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    const SizedBox(height: 80),
                                    Center(child: Text('لا نتائج للبحث', style: context.text.bodyMedium)),
                                  ],
                                )
                              : ListView.separated(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                      MqSpacing.lg, MqSpacing.md, MqSpacing.lg, MqSpacing.xxxl),
                                  itemCount: items.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: MqSpacing.sm),
                                  itemBuilder: (ctx, i) => _ConversationTile(
                                    conversation: items[i],
                                    onTap: () => _openConversation(items[i]),
                                  ),
                                ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchBar(BuildContext context) {
    final mq = context.mq;
    return Container(
      decoration: BoxDecoration(
        color: mq.page,
        border: Border(bottom: BorderSide(color: mq.line)),
      ),
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.sm, MqSpacing.lg, MqSpacing.md),
      child: TextField(
        controller: _search,
        decoration: InputDecoration(
          hintText: 'ابحث في المحادثات…',
          prefixIcon: const Icon(Icons.search_rounded),
          isDense: true,
        ),
      ),
    );
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

  Future<void> _openConversation(ChatConversation c) async {
    if (_myUserId == null) return;
    _ctrl.markConversationOpened(c.id);
    await Get.to(
      () => StudentConversationScreen(
        conversationId: c.id,
        initialTitle: c.displayName(),
        myUserId: _myUserId!,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Helpers
// ---------------------------------------------------------------------------

({String label, MqBadgeTone tone}) chatRoleBadge(ChatConversation c) {
  if (c.isGroup) return (label: 'مجموعة', tone: MqBadgeTone.accent);
  switch (c.peer?.userType) {
    case 'teacher':
      return (label: 'أستاذ', tone: MqBadgeTone.accent);
    case 'super_admin':
      return (label: 'إدارة', tone: MqBadgeTone.orange);
    case 'student':
      return (label: 'طالب', tone: MqBadgeTone.neutral);
    default:
      return (label: '', tone: MqBadgeTone.neutral);
  }
}

String? resolveProfileUrl(String? path) {
  final p = path?.trim() ?? '';
  if (p.isEmpty) return null;
  if (p.startsWith('http://') || p.startsWith('https://') || p.startsWith('data:')) return p;
  final base = AppConfig.serverBaseUrl.replaceAll(RegExp(r'/+$'), '');
  return p.startsWith('/') ? '$base$p' : '$base/$p';
}

/// Chat avatar: image when available, group icon for groups, else initials.
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({super.key, required this.name, required this.isGroup, this.imagePath, this.size = 48});
  final String name;
  final bool isGroup;
  final String? imagePath;
  final double size;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final url = resolveProfileUrl(imagePath);
    final fallback = Container(
      color: isGroup ? mq.orangeSoft : mq.accentSoft,
      alignment: Alignment.center,
      child: isGroup
          ? Icon(Icons.groups_rounded, color: mq.orangeDeep, size: size * 0.5)
          : Text(name.isNotEmpty ? name.characters.first : '؟',
              style: context.text.titleMedium?.copyWith(color: mq.accent)),
    );
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: (url == null || isGroup)
            ? fallback
            : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Sub-widgets
// ---------------------------------------------------------------------------

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.onTap});
  final ChatConversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final unread = conversation.unreadCount > 0;
    final role = chatRoleBadge(conversation);
    final timeStr = conversation.lastMessageAt != null ? _relativeTime(conversation.lastMessageAt!) : '';

    return MqCard(
      onTap: onTap,
      color: unread ? mq.accentSoft.withValues(alpha: 0.5) : mq.card,
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Row(
        children: [
          ChatAvatar(
            name: conversation.displayName(),
            isGroup: conversation.isGroup,
            imagePath: conversation.peer?.profileImagePath,
          ),
          MqSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(conversation.displayName(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall),
                    ),
                    MqSpacing.gapXs,
                    Text(timeStr, style: context.text.labelSmall),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (role.label.isNotEmpty) ...[
                      MqBadge(label: role.label, tone: role.tone),
                      MqSpacing.gapXs,
                    ],
                    if (conversation.mode == ConversationMode.announceOnly) ...[
                      Icon(Icons.campaign_outlined, size: 13, color: mq.ink3),
                      MqSpacing.gapXxs,
                    ],
                    Expanded(
                      child: Text(
                        _preview(conversation),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(
                          color: unread ? mq.ink : mq.ink2,
                          fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (unread) ...[
                      MqSpacing.gapXs,
                      MqBadge(
                        label: conversation.unreadCount > 99 ? '99+' : '${conversation.unreadCount}',
                        tone: MqBadgeTone.accent,
                        solid: true,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
    if (diff.inDays < 1) return DateFormat('HH:mm').format(t);
    if (diff.inDays < 7) return DateFormat('EEE', 'ar').format(t);
    return DateFormat('dd/MM').format(t);
  }
}

class _Skeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    Widget bar(double w, double h) =>
        Container(width: w, height: h, decoration: BoxDecoration(color: mq.fill2, borderRadius: MqRadius.brSm));
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.md, MqSpacing.lg, MqSpacing.lg),
      itemCount: 7,
      separatorBuilder: (_, _) => const SizedBox(height: MqSpacing.sm),
      itemBuilder: (_, _) => MqCard(
        padding: const EdgeInsets.all(MqSpacing.md),
        child: Row(
          children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: mq.fill2, shape: BoxShape.circle)),
            MqSpacing.gapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [bar(150, 12), const SizedBox(height: 8), bar(210, 10)],
              ),
            ),
          ],
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
            padding: const EdgeInsets.all(MqSpacing.lg),
            decoration: BoxDecoration(color: mq.accentSoft, shape: BoxShape.circle),
            child: Icon(Icons.forum_outlined, size: 44, color: mq.accent),
          ),
          MqSpacing.gapMd,
          Text('لا توجد محادثات بعد', style: context.text.titleMedium),
          MqSpacing.gapXs,
          Text('سيظهر هنا تواصلك مع معلميك والمجموعات التي تنتمي إليها.',
              textAlign: TextAlign.center, style: context.text.bodySmall),
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
            Icon(Icons.wifi_off_rounded, size: 44, color: mq.error),
            MqSpacing.gapMd,
            Text(message, textAlign: TextAlign.center, style: context.text.bodyMedium),
            MqSpacing.gapMd,
            MqButton(label: 'إعادة المحاولة', icon: Icons.refresh_rounded, expand: false, onPressed: () => onRetry()),
          ],
        ),
      ),
    );
  }
}

/// Thin banner shown while the realtime socket is disconnected. Reads the
/// existing [ChatSocketService.isConnected] flag (no realtime logic changed);
/// a short timer drives the rebuild since the service exposes no Rx state.
class ChatConnectionBanner extends StatefulWidget {
  const ChatConnectionBanner({super.key});
  @override
  State<ChatConnectionBanner> createState() => ChatConnectionBannerState();
}

class ChatConnectionBannerState extends State<ChatConnectionBanner> {
  Timer? _t;
  bool _connected = true;

  @override
  void initState() {
    super.initState();
    _connected = ChatSocketService.instance.isConnected;
    _t = Timer.periodic(const Duration(seconds: 2), (_) {
      final c = ChatSocketService.instance.isConnected;
      if (c != _connected && mounted) setState(() => _connected = c);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_connected) return const SizedBox.shrink();
    final mq = context.mq;
    return Container(
      width: double.infinity,
      color: mq.orangeSoft,
      padding: const EdgeInsets.symmetric(horizontal: MqSpacing.lg, vertical: MqSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2, color: mq.orangeDeep),
          ),
          MqSpacing.gapSm,
          Text('جارٍ إعادة الاتصال…',
              style: context.text.labelMedium?.copyWith(color: mq.orangeDeep)),
        ],
      ),
    );
  }
}
