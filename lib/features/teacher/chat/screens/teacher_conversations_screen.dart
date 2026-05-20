import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../controllers/conversations_controller.dart';
import '../models/chat_models.dart';
import 'teacher_conversation_screen.dart';
import 'teacher_create_group_screen.dart';

class TeacherConversationsScreen extends StatefulWidget {
  const TeacherConversationsScreen({super.key});

  @override
  State<TeacherConversationsScreen> createState() =>
      _TeacherConversationsScreenState();
}

class _TeacherConversationsScreenState
    extends State<TeacherConversationsScreen> {
  late final ConversationsController _ctrl;
  String? _myUserId;

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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('المحادثات'),
        actions: [
          IconButton(
            tooltip: 'مجموعة جديدة',
            icon: const Icon(Icons.group_add_outlined),
            onPressed: _openCreateGroup,
          ),
        ],
      ),
      body: Obx(() {
        if (_ctrl.loading.value && _ctrl.conversations.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_ctrl.error.value != null && _ctrl.conversations.isEmpty) {
          return _ErrorView(
            message: _ctrl.error.value!,
            onRetry: _ctrl.fetch,
          );
        }
        return RefreshIndicator(
          onRefresh: () => _ctrl.fetch(isRefresh: true),
          child: _ctrl.conversations.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    _EmptyConversations(),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _ctrl.conversations.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                  ),
                  itemBuilder: (ctx, i) => _ConversationTile(
                    conversation: _ctrl.conversations[i],
                    onTap: () => _openConversation(_ctrl.conversations[i]),
                  ),
                ),
        );
      }),
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
//  Sub-widgets
// ---------------------------------------------------------------------------

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.onTap});
  final ChatConversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isGroup = conversation.isGroup;
    final timeStr = conversation.lastMessageAt != null
        ? _relativeTime(conversation.lastMessageAt!)
        : '';
    return ListTile(
      onTap: onTap,
      leading: _Avatar(
        name: conversation.displayName(),
        imagePath: isGroup ? conversation.imagePath : conversation.peer?.profileImagePath,
        isGroup: isGroup,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              conversation.displayName(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (conversation.mode == ConversationMode.announceOnly)
            Padding(
              padding: const EdgeInsets.only(right: 6, left: 6),
              child: Icon(Icons.campaign_outlined,
                  size: 14, color: cs.onSurfaceVariant),
            ),
          Text(timeStr,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              _preview(conversation),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: conversation.unreadCount > 0
                    ? cs.onSurface
                    : cs.onSurfaceVariant,
                fontWeight: conversation.unreadCount > 0
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),
          if (conversation.unreadCount > 0) ...[
            const SizedBox(width: 8),
            _UnreadBadge(count: conversation.unreadCount),
          ],
        ],
      ),
    );
  }

  String _preview(ChatConversation c) {
    final m = c.lastMessage;
    if (m == null) return c.isGroup ? 'لا توجد رسائل بعد' : 'ابدأ المحادثة';
    if (m.isDeleted) return 'تم حذف هذه الرسالة';
    if ((m.body ?? '').trim().isNotEmpty) {
      return m.body!.trim();
    }
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

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.name,
    required this.imagePath,
    required this.isGroup,
  });
  final String name;
  final String? imagePath;
  final bool isGroup;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initials = (name.isNotEmpty ? name.characters.first : '?');
    return CircleAvatar(
      radius: 24,
      backgroundColor: isGroup
          ? cs.tertiaryContainer
          : cs.primary.withValues(alpha: 0.15),
      foregroundColor: cs.primary,
      child: isGroup
          ? Icon(Icons.groups_outlined, color: cs.tertiary)
          : Text(initials,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          color: cs.onPrimary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _EmptyConversations extends StatelessWidget {
  const _EmptyConversations();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.forum_outlined,
              size: 56, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          const Text('لا توجد محادثات بعد',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            'أنشئ مجموعة جديدة أو ابدأ محادثة خاصة مع طالب',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
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
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: cs.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => onRetry(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
