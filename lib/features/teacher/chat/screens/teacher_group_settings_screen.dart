// Group management screen.
//
// Surface:
//   - Header card: name + description + mode toggle (open vs announce_only).
//     Editable by owner only.
//   - Members list with per-row actions:
//     - Promote / demote (owner only)
//     - Mute (1h / 24h / unmute)
//     - Remove
//   - Add members (UUID paste — same pattern as create).
//   - Danger zone: archive (owner only).
//
// All mutations call REST; the server emits `group:updated` /
// `member:added` / `member:removed` which the per-conversation controller
// listens to. This screen also refreshes locally on every action so the
// user sees instant feedback.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/utils/time_format.dart';

import '../models/chat_models.dart';
import '../services/chat_api_service.dart';
import '../widgets/student_picker_sheet.dart';

class TeacherGroupSettingsScreen extends StatefulWidget {
  const TeacherGroupSettingsScreen({
    super.key,
    required this.conversationId,
    required this.myUserId,
  });
  final String conversationId;
  final String myUserId;

  @override
  State<TeacherGroupSettingsScreen> createState() =>
      _TeacherGroupSettingsScreenState();
}

class _TeacherGroupSettingsScreenState
    extends State<TeacherGroupSettingsScreen> {
  ChatConversation? _conv;
  List<ChatMember> _members = const [];
  bool _loading = true;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final convData = await ChatApiService.instance.getConversation(
        widget.conversationId,
      );
      final c = convData['conversation'];
      if (c is Map) {
        final conv = ChatConversation.fromJson(Map<String, dynamic>.from(c));
        // /chat/conversations/:id returns the bare row; pull myRole from
        // `data.me.role` so owner/admin gates (edit, archive, promote)
        // work in this screen.
        final me = convData['me'];
        if (me is Map) {
          final roleStr = me['role']?.toString();
          if (roleStr == 'owner') {
            conv.myRole = MemberRole.owner;
          } else if (roleStr == 'admin') {
            conv.myRole = MemberRole.admin;
          } else {
            conv.myRole = MemberRole.member;
          }
        }
        _conv = conv;
      }
      _members = await ChatApiService.instance.listMembers(
        widget.conversationId,
      );
    } catch (e) {
      _error = _humanise(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات المجموعة')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _HeaderCard(
                    conversation: _conv!,
                    canEdit: _conv!.isOwner,
                    saving: _saving,
                    onSave: _saveHeader,
                  ),
                  _MembersSection(
                    conv: _conv!,
                    members: _members,
                    myUserId: widget.myUserId,
                    onPromote: (uid) => _setRole(uid, MemberRole.admin),
                    onDemote: (uid) => _setRole(uid, MemberRole.member),
                    onMute: _muteMember,
                    onUnmute: _unmuteMember,
                    onRemove: _removeMember,
                    onAdd: _addMembersFlow,
                  ),
                  if (_conv!.isOwner) _DangerZone(onArchive: _archive),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  // ---------------------------------------------------------------------------
  //  Mutations
  // ---------------------------------------------------------------------------

  Future<void> _saveHeader({
    required String name,
    required String description,
    required ConversationMode mode,
  }) async {
    setState(() => _saving = true);
    try {
      await ChatApiService.instance.updateGroup(
        widget.conversationId,
        name: name,
        description: description,
        mode: mode,
      );
      await _load();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setRole(String userId, MemberRole role) async {
    try {
      await ChatApiService.instance.updateMember(
        widget.conversationId,
        userId,
        role: role,
      );
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _muteMember(String userId, Duration duration) async {
    try {
      await ChatApiService.instance.updateMember(
        widget.conversationId,
        userId,
        muteUntil: DateTime.now().add(duration),
      );
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _unmuteMember(String userId) async {
    try {
      await ChatApiService.instance.updateMember(
        widget.conversationId,
        userId,
        unmute: true,
      );
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _removeMember(String userId, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إزالة عضو'),
        content: Text('هل تريد إزالة "$name" من المجموعة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ChatApiService.instance.removeMember(widget.conversationId, userId);
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _addMembersFlow() async {
    // Exclude every active member already in the group so the picker doesn't
    // show duplicates. Includes the owner (`me`) which would otherwise be a
    // no-op skip on the server.
    final existing = _members
        .where((m) => m.isActive)
        .map((m) => m.userId)
        .toSet();

    final picked = await StudentPickerSheet.show(
      context,
      title: 'إضافة طلاب',
      excludeUserIds: existing,
    );
    if (picked == null || picked.isEmpty) return;
    try {
      await ChatApiService.instance.addMembers(
        widget.conversationId,
        picked.map((p) => p.id).toList(growable: false),
      );
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _archive() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('أرشفة المجموعة'),
        content: const Text(
          'سيتم أرشفة المجموعة وفقدان جميع الأعضاء الوصول إليها. هذه العملية نهائية.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.errorContainer,
            ),
            child: const Text('أرشفة'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ChatApiService.instance.archiveGroup(widget.conversationId);
      if (!mounted) return;
      Get.back();
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('فشلت العملية: ${_humanise(e)}')));
  }

  String _humanise(Object e) {
    final s = e.toString();
    if (s.contains('FORBIDDEN')) return 'لا تملك صلاحية';
    if (s.contains('BUSINESS_RULE')) return 'العملية غير مسموحة';
    if (s.contains('NOT_FOUND')) return 'العضو غير موجود';
    return 'حدث خطأ';
  }
}

// ---------------------------------------------------------------------------
//  Sub-widgets
// ---------------------------------------------------------------------------

class _HeaderCard extends StatefulWidget {
  const _HeaderCard({
    required this.conversation,
    required this.canEdit,
    required this.saving,
    required this.onSave,
  });
  final ChatConversation conversation;
  final bool canEdit;
  final bool saving;
  final Future<void> Function({
    required String name,
    required String description,
    required ConversationMode mode,
  })
  onSave;

  @override
  State<_HeaderCard> createState() => _HeaderCardState();
}

class _HeaderCardState extends State<_HeaderCard> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late ConversationMode _mode;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.conversation.name ?? '');
    _description = TextEditingController(
      text: widget.conversation.description ?? '',
    );
    _mode = widget.conversation.mode;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.groups_outlined, color: cs.primary),
                const SizedBox(width: 8),
                const Text(
                  'بيانات المجموعة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              enabled: widget.canEdit,
              decoration: const InputDecoration(
                labelText: 'الاسم',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _description,
              enabled: widget.canEdit,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'الوصف',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'الوضع',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 4),
            SegmentedButton<ConversationMode>(
              segments: const [
                ButtonSegment(
                  value: ConversationMode.open,
                  icon: Icon(Icons.forum_outlined),
                  label: Text('الجميع'),
                ),
                ButtonSegment(
                  value: ConversationMode.announceOnly,
                  icon: Icon(Icons.campaign_outlined),
                  label: Text('إعلانات'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: widget.canEdit
                  ? (s) => setState(() => _mode = s.first)
                  : null,
            ),
            if (widget.canEdit) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: widget.saving
                      ? null
                      : () => widget.onSave(
                          name: _name.text.trim(),
                          description: _description.text.trim(),
                          mode: _mode,
                        ),
                  icon: widget.saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('حفظ'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MembersSection extends StatelessWidget {
  const _MembersSection({
    required this.conv,
    required this.members,
    required this.myUserId,
    required this.onPromote,
    required this.onDemote,
    required this.onMute,
    required this.onUnmute,
    required this.onRemove,
    required this.onAdd,
  });
  final ChatConversation conv;
  final List<ChatMember> members;
  final String myUserId;
  final Future<void> Function(String userId) onPromote;
  final Future<void> Function(String userId) onDemote;
  final Future<void> Function(String userId, Duration duration) onMute;
  final Future<void> Function(String userId) onUnmute;
  final Future<void> Function(String userId, String name) onRemove;
  final Future<void> Function() onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people_outline, color: cs.primary),
                const SizedBox(width: 8),
                const Text(
                  'الأعضاء',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Spacer(),
                if (conv.canManage)
                  TextButton.icon(
                    onPressed: () => onAdd(),
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: const Text('إضافة'),
                  ),
              ],
            ),
            ...members.map(
              (m) => _MemberTile(
                member: m,
                myUserId: myUserId,
                viewerCanManage: conv.canManage,
                viewerIsOwner: conv.isOwner,
                onPromote: onPromote,
                onDemote: onDemote,
                onMute: onMute,
                onUnmute: onUnmute,
                onRemove: onRemove,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.myUserId,
    required this.viewerCanManage,
    required this.viewerIsOwner,
    required this.onPromote,
    required this.onDemote,
    required this.onMute,
    required this.onUnmute,
    required this.onRemove,
  });
  final ChatMember member;
  final String myUserId;
  final bool viewerCanManage;
  final bool viewerIsOwner;
  final Future<void> Function(String userId) onPromote;
  final Future<void> Function(String userId) onDemote;
  final Future<void> Function(String userId, Duration duration) onMute;
  final Future<void> Function(String userId) onUnmute;
  final Future<void> Function(String userId, String name) onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMe = member.userId == myUserId;
    final isOwner = member.role == MemberRole.owner;
    final isAdmin = member.role == MemberRole.admin;
    final name = member.profile?.name ?? 'عضو';
    final subtitleBits = <String>[
      if (isOwner) 'مالك' else if (isAdmin) 'مشرف' else 'عضو',
      if (member.isMutedNow)
        'مكتوم حتى ${formatDateTime12(member.isMutedByAdminUntil!)}',
    ];

    final canActOnThisMember = viewerCanManage && !isMe && !isOwner;
    final canChangeRole = viewerIsOwner && !isMe && !isOwner;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: cs.primary.withValues(alpha: 0.12),
        child: Text(
          name.isNotEmpty ? name.characters.first : '?',
          style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      subtitle: Text(
        subtitleBits.join(' · '),
        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
      ),
      trailing: (canActOnThisMember || canChangeRole)
          ? PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (_) => [
                if (canChangeRole && !isAdmin)
                  const PopupMenuItem(
                    value: 'promote',
                    child: Text('ترقية إلى مشرف'),
                  ),
                if (canChangeRole && isAdmin)
                  const PopupMenuItem(
                    value: 'demote',
                    child: Text('إنزال إلى عضو عادي'),
                  ),
                if (canActOnThisMember && !member.isMutedNow) ...[
                  const PopupMenuItem(
                    value: 'mute_1h',
                    child: Text('كتم ساعة'),
                  ),
                  const PopupMenuItem(
                    value: 'mute_24h',
                    child: Text('كتم يوم'),
                  ),
                ],
                if (canActOnThisMember && member.isMutedNow)
                  const PopupMenuItem(
                    value: 'unmute',
                    child: Text('إلغاء الكتم'),
                  ),
                if (canActOnThisMember)
                  const PopupMenuItem(value: 'remove', child: Text('إزالة')),
              ],
              onSelected: (v) async {
                switch (v) {
                  case 'promote':
                    await onPromote(member.userId);
                  case 'demote':
                    await onDemote(member.userId);
                  case 'mute_1h':
                    await onMute(member.userId, const Duration(hours: 1));
                  case 'mute_24h':
                    await onMute(member.userId, const Duration(hours: 24));
                  case 'unmute':
                    await onUnmute(member.userId);
                  case 'remove':
                    await onRemove(member.userId, name);
                }
              },
            )
          : null,
    );
  }
}

class _DangerZone extends StatelessWidget {
  const _DangerZone({required this.onArchive});
  final Future<void> Function() onArchive;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.all(12),
      color: cs.errorContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_outlined, color: cs.error),
                const SizedBox(width: 8),
                Text(
                  'منطقة خطرة',
                  style: TextStyle(
                    color: cs.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'أرشفة المجموعة عملية نهائية — لا يمكن استرجاعها.',
              style: TextStyle(fontSize: 12, color: cs.onErrorContainer),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => onArchive(),
              style: OutlinedButton.styleFrom(foregroundColor: cs.error),
              icon: const Icon(Icons.archive_outlined),
              label: const Text('أرشفة المجموعة'),
            ),
          ],
        ),
      ),
    );
  }
}
