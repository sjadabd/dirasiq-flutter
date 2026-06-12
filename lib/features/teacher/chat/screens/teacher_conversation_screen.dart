// Single-conversation screen (Teacher Design System pass).
//
// Presentation only — the ConversationController (fetch / pagination / send /
// typing / pin / delete), the attachment upload, the message menu, and the
// group-settings navigation are UNCHANGED. Restyled to the teacher design
// system: chat-style header, design-system bubbles, and a rounded composer.
//
//   - SEND path is REST (controller.send); RECEIVE is socket — untouched.
//   - Long-press own message → delete (≤5 min) / pin (owner/admin).
//   - announce_only + member → composer disabled with hint.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/config/app_config.dart';
import '../../shared/design/teacher_design.dart';
import '../controllers/conversation_controller.dart';
import '../models/chat_models.dart';
import '../services/chat_api_service.dart';
import 'teacher_group_settings_screen.dart';

class TeacherConversationScreen extends StatefulWidget {
  const TeacherConversationScreen({
    super.key,
    required this.conversationId,
    required this.initialTitle,
    required this.myUserId,
  });

  final String conversationId;
  final String initialTitle;
  final String myUserId;

  @override
  State<TeacherConversationScreen> createState() =>
      _TeacherConversationScreenState();
}

class _TeacherConversationScreenState extends State<TeacherConversationScreen> {
  late final ConversationController _ctrl;
  late final TextEditingController _composer;
  late final ScrollController _scroll;
  late final FocusNode _messageFocus;
  final _picker = ImagePicker();
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _composer = TextEditingController();
    _scroll = ScrollController();
    _messageFocus = FocusNode(debugLabel: 'chat-composer');
    _ctrl = Get.put(
      ConversationController(
        conversationId: widget.conversationId,
        myUserId: widget.myUserId,
      ),
      tag: 'conv-${widget.conversationId}',
    );
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _composer.dispose();
    _messageFocus.dispose();
    Get.delete<ConversationController>(tag: 'conv-${widget.conversationId}');
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _ctrl.loadOlder();
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
            resizeToAvoidBottomInset: true,
            appBar: _appBar(context),
            body: Obx(() {
              if (_ctrl.loading.value && _ctrl.messages.isEmpty) {
                return Center(
                    child: CircularProgressIndicator(color: mq.accent));
              }
              if (_ctrl.error.value != null && _ctrl.messages.isEmpty) {
                return _ErrorView(
                    message: _ctrl.error.value!, onRetry: _ctrl.fetch);
              }
              return Column(
                children: [
                  _AnnounceOnlyBanner(controller: _ctrl),
                  Expanded(
                    child: _ctrl.messages.isEmpty
                        ? const _EmptyMessages()
                        : ListView.builder(
                            controller: _scroll,
                            reverse: true,
                            padding: const EdgeInsets.symmetric(
                                horizontal: MqSpacing.sm,
                                vertical: MqSpacing.sm),
                            itemCount: _ctrl.messages.length +
                                (_ctrl.loadingMore.value ? 1 : 0),
                            itemBuilder: (ctx, idx) {
                              if (_ctrl.loadingMore.value &&
                                  idx == _ctrl.messages.length) {
                                return const Padding(
                                  padding:
                                      EdgeInsets.symmetric(vertical: MqSpacing.md),
                                  child: Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  ),
                                );
                              }
                              final m = _ctrl.messages[idx];
                              final isMine = m.senderId == widget.myUserId;
                              return _Bubble(
                                message: m,
                                isMine: isMine,
                                onLongPress: () => _showMessageMenu(m, isMine),
                              );
                            },
                          ),
                  ),
                  Obx(() {
                    final typing = _ctrl.typingUserName.value;
                    if (typing == null) return const SizedBox.shrink();
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: MqSpacing.lg, vertical: MqSpacing.xs),
                      child: Text('$typing يكتب…',
                          style: context.text.labelSmall?.copyWith(
                              color: mq.ink3, fontStyle: FontStyle.italic)),
                    );
                  }),
                  _Composer(
                    controller: _composer,
                    focusNode: _messageFocus,
                    canSend: _canSend(),
                    uploading: _uploading,
                    onSubmit: _submit,
                    onAttach: _pickImage,
                    onTyping: _ctrl.typing,
                  ),
                ],
              );
            }),
          );
        }),
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
      leadingWidth: 48,
      leading: Align(
        child: _HeaderChip(
          icon: Icons.arrow_forward_rounded,
          tooltip: 'رجوع',
          onTap: () => Navigator.of(context).maybePop(),
        ),
      ),
      title: Obx(() {
        final c = _ctrl.conversation.value;
        final name = c?.displayName() ?? widget.initialTitle;
        final isGroup = c?.isGroup ?? false;
        return Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isGroup ? mq.orangeSoft : mq.accentSoft,
                shape: BoxShape.circle,
                border: Border.all(
                    color: isGroup ? mq.orangeLine : mq.accentLine),
              ),
              alignment: Alignment.center,
              child: isGroup
                  ? Icon(Icons.groups_2_outlined, size: 18, color: mq.orangeDeep)
                  : Text(name.isNotEmpty ? name.characters.first : '؟',
                      style: MqTypography.mono(
                          color: mq.accent, size: 14, weight: FontWeight.w700)),
            ),
            const SizedBox(width: MqSpacing.sm),
            Expanded(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall),
            ),
          ],
        );
      }),
      actions: [
        Obx(() {
          final c = _ctrl.conversation.value;
          if (c == null || !c.isGroup) return const SizedBox.shrink();
          return _HeaderChip(
            icon: Icons.info_outline_rounded,
            tooltip: 'إعدادات المجموعة',
            onTap: () => _openSettings(c),
          );
        }),
        const SizedBox(width: MqSpacing.sm),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: mq.line),
      ),
    );
  }

  bool _canSend() {
    final c = _ctrl.conversation.value;
    if (c == null) return true;
    if (c.mode == ConversationMode.announceOnly && !c.canManage) return false;
    return true;
  }

  Future<void> _submit() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    _composer.clear();
    await _ctrl.send(body: text);
  }

  Future<void> _pickImage() async {
    final XFile? picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final att = await ChatApiService.instance.uploadAttachment(
        conversationId: widget.conversationId,
        filePath: picked.path,
        declaredMime: picked.mimeType,
      );
      await _ctrl.send(attachmentIds: [att.id]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر رفع الصورة: ${_errorMsg(e)}')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _errorMsg(Object e) {
    final s = e.toString();
    if (s.contains('file_too_large')) return 'الملف كبير جداً';
    if (s.contains('unknown_mime') || s.contains('unsupported_mime')) {
      return 'صيغة غير مدعومة';
    }
    return 'حدث خطأ';
  }

  void _openSettings(ChatConversation conv) {
    Get.to(
      () => TeacherGroupSettingsScreen(
        conversationId: conv.id,
        myUserId: widget.myUserId,
      ),
    );
  }

  void _showMessageMenu(ChatMessage m, bool isMine) {
    final canDeleteOwn =
        isMine && DateTime.now().difference(m.createdAt).inMinutes < 5;
    final isOwnerOrAdmin = _ctrl.conversation.value?.canManage == true;
    final canDelete = canDeleteOwn || isOwnerOrAdmin;
    final canPin = isOwnerOrAdmin && _ctrl.conversation.value?.isGroup == true;

    if (!canDelete && !canPin) return;
    if (m.isDeleted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Theme(
        data: isDark ? MqTheme.dark() : MqTheme.light(),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Builder(builder: (ctx) {
            final mq = ctx.mq;
            return Container(
              decoration: BoxDecoration(
                color: mq.card,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(MqRadius.xl)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: MqSpacing.sm),
                      decoration: BoxDecoration(
                          color: mq.line, borderRadius: MqRadius.brPill),
                    ),
                    if (canPin)
                      ListTile(
                        leading: Icon(
                            m.isPinned
                                ? Icons.push_pin
                                : Icons.push_pin_outlined,
                            color: mq.accent),
                        title: Text(
                            m.isPinned ? 'إلغاء التثبيت' : 'تثبيت الرسالة'),
                        onTap: () async {
                          Navigator.of(ctx).pop();
                          try {
                            await _ctrl.togglePin(m);
                          } catch (e) {
                            _showError(e);
                          }
                        },
                      ),
                    if (canDelete)
                      ListTile(
                        leading:
                            Icon(Icons.delete_outline_rounded, color: mq.error),
                        title: Text('حذف الرسالة',
                            style: TextStyle(color: mq.error)),
                        onTap: () async {
                          Navigator.of(ctx).pop();
                          try {
                            await _ctrl.deleteMessage(m);
                          } catch (e) {
                            _showError(e);
                          }
                        },
                      ),
                    const SizedBox(height: MqSpacing.sm),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('فشلت العملية: ${_errorMsg(e)}')),
    );
  }
}

// ---------------------------------------------------------------------------
//  Sub-widgets
// ---------------------------------------------------------------------------

class _HeaderChip extends StatelessWidget {
  const _HeaderChip(
      {required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: mq.fill,
        shape: RoundedRectangleBorder(
          borderRadius: MqRadius.brMd,
          side: BorderSide(color: mq.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: MqSize.iconSm, color: mq.ink2),
          ),
        ),
      ),
    );
  }
}

class _AnnounceOnlyBanner extends StatelessWidget {
  const _AnnounceOnlyBanner({required this.controller});
  final ConversationController controller;
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final c = controller.conversation.value;
      if (c == null || c.mode != ConversationMode.announceOnly) {
        return const SizedBox.shrink();
      }
      final mq = context.mq;
      final t = context.teacher;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: MqSpacing.lg, vertical: MqSpacing.sm),
        color: t.warningSoft,
        child: Row(
          children: [
            Icon(Icons.campaign_outlined, size: 15, color: t.warning),
            const SizedBox(width: MqSpacing.sm),
            Expanded(
              child: Text(
                c.canManage
                    ? 'وضع الإعلانات: فقط أنت ومشرفو المجموعة يمكنهم الإرسال.'
                    : 'هذه المجموعة للإعلانات فقط — لا يمكن للأعضاء الإرسال.',
                style: context.text.labelSmall?.copyWith(color: mq.ink2),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _EmptyMessages extends StatelessWidget {
  const _EmptyMessages();
  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: mq.fill2, shape: BoxShape.circle),
            child: Icon(Icons.chat_bubble_outline, size: 30, color: mq.ink3),
          ),
          const SizedBox(height: MqSpacing.md),
          Text('لا توجد رسائل بعد',
              style: context.text.bodyMedium?.copyWith(color: mq.ink2)),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.isMine,
    required this.onLongPress,
  });
  final ChatMessage message;
  final bool isMine;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final t = context.teacher;
    final deleted = message.isDeleted;
    final bg = deleted
        ? mq.fill2
        : (isMine ? mq.accent : mq.card);
    final fg = deleted ? mq.ink3 : (isMine ? mq.onAccent : mq.ink);
    final time = DateFormat('HH:mm').format(message.createdAt.toLocal());

    return Align(
      alignment: isMine ? Alignment.centerLeft : Alignment.centerRight,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: MqSpacing.xs),
          padding: const EdgeInsets.symmetric(
              horizontal: MqSpacing.md, vertical: MqSpacing.sm),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.76),
          decoration: BoxDecoration(
            color: bg,
            border: (!isMine && !deleted) ? Border.all(color: mq.line) : null,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft:
                  isMine ? const Radius.circular(4) : const Radius.circular(16),
              bottomRight:
                  isMine ? const Radius.circular(16) : const Radius.circular(4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isMine && !deleted && message.sender != null) ...[
                Text(message.sender!.name,
                    style: context.text.labelSmall?.copyWith(
                        color: mq.accent, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
              ],
              if (message.isPinned)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.push_pin,
                          size: 12,
                          color: isMine ? mq.onAccent : t.warning),
                      const SizedBox(width: MqSpacing.xs),
                      Text('مثبّتة',
                          style: context.text.labelSmall?.copyWith(
                              color: isMine ? mq.onAccent : t.warning,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              if (deleted)
                Text('تم حذف هذه الرسالة',
                    style: context.text.bodySmall?.copyWith(
                        color: mq.ink3, fontStyle: FontStyle.italic))
              else ...[
                for (final a in message.attachments) _AttachmentView(att: a),
                if ((message.body ?? '').isNotEmpty)
                  Text(message.body!,
                      style: context.text.bodyMedium
                          ?.copyWith(color: fg, height: 1.35)),
              ],
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(time,
                      style: context.text.labelSmall?.copyWith(
                          color: fg.withValues(alpha: 0.6), fontSize: 10)),
                  if (isMine && !deleted) ...[
                    const SizedBox(width: MqSpacing.xs),
                    _StatusGlyph(status: message.status, color: fg),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusGlyph extends StatelessWidget {
  const _StatusGlyph({required this.status, required this.color});
  final MessageStatus status;
  final Color color;
  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return Icon(Icons.schedule, size: 11, color: color.withValues(alpha: 0.6));
      case MessageStatus.failed:
        return Icon(Icons.error_outline, size: 11, color: context.mq.error);
      case MessageStatus.sent:
        return Icon(Icons.done, size: 11, color: color.withValues(alpha: 0.6));
    }
  }
}

class _AttachmentView extends StatelessWidget {
  const _AttachmentView({required this.att});
  final ChatAttachment att;
  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final url = att.url.startsWith('http')
        ? att.url
        : '${AppConfig.chatBaseUrl}${att.url}';
    final thumb = att.thumbnailUrl == null
        ? null
        : (att.thumbnailUrl!.startsWith('http')
            ? att.thumbnailUrl!
            : '${AppConfig.chatBaseUrl}${att.thumbnailUrl!}');

    if (att.isImage) {
      return Padding(
        padding: const EdgeInsets.only(bottom: MqSpacing.xs),
        child: ClipRRect(
          borderRadius: MqRadius.brMd,
          child: Image.network(
            thumb ?? url,
            width: 220,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 220,
              height: 140,
              color: mq.fill2,
              alignment: Alignment.center,
              child: Icon(Icons.broken_image_outlined, color: mq.ink3),
            ),
          ),
        ),
      );
    }

    final iconData = att.isVideo
        ? Icons.video_file_outlined
        : (att.isPdf
            ? Icons.picture_as_pdf_outlined
            : Icons.insert_drive_file_outlined);
    return Padding(
      padding: const EdgeInsets.only(bottom: MqSpacing.xs),
      child: Container(
        padding: const EdgeInsets.all(MqSpacing.sm),
        decoration: BoxDecoration(
          color: mq.card,
          borderRadius: MqRadius.brMd,
          border: Border.all(color: mq.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconData, size: 22, color: mq.accent),
            const SizedBox(width: MqSpacing.sm),
            Flexible(
              child: Text(att.originalName ?? att.url.split('/').last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.canSend,
    required this.uploading,
    required this.onSubmit,
    required this.onAttach,
    required this.onTyping,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool canSend;
  final bool uploading;
  final Future<void> Function() onSubmit;
  final Future<void> Function() onAttach;
  final VoidCallback onTyping;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
            MqSpacing.sm, MqSpacing.sm, MqSpacing.sm, MqSpacing.sm),
        decoration: BoxDecoration(
          color: mq.card,
          border: Border(top: BorderSide(color: mq.line)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _RoundIcon(
              icon: uploading ? null : Icons.attach_file_outlined,
              loading: uploading,
              onTap: canSend && !uploading ? () => onAttach() : null,
              filled: false,
            ),
            const SizedBox(width: MqSpacing.xs),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: canSend,
                  autofocus: false,
                  onChanged: (_) => onTyping(),
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  keyboardType: TextInputType.multiline,
                  style: context.text.bodyMedium,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: mq.fill,
                    hintText: canSend
                        ? 'اكتب رسالتك…'
                        : 'لا يمكنك الإرسال في هذه المجموعة',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: MqSpacing.md, vertical: MqSpacing.sm),
                    border: const OutlineInputBorder(
                      borderRadius: MqRadius.brPill,
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: MqRadius.brPill,
                      borderSide: BorderSide(color: mq.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: MqRadius.brPill,
                      borderSide: BorderSide(color: mq.accent, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: MqSpacing.xs),
            _RoundIcon(
              icon: Icons.send_rounded,
              onTap: canSend ? () => onSubmit() : null,
              filled: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.onTap,
    required this.filled,
    this.loading = false,
  });
  final IconData? icon;
  final VoidCallback? onTap;
  final bool filled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final disabled = onTap == null;
    final bg = filled
        ? (disabled ? mq.fill2 : mq.accent)
        : mq.fill;
    final fg = filled ? mq.onAccent : mq.ink2;
    return Material(
      color: bg,
      shape: filled
          ? const CircleBorder()
          : RoundedRectangleBorder(
              borderRadius: MqRadius.brMd,
              side: BorderSide(color: mq.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: loading
              ? Padding(
                  padding: const EdgeInsets.all(13),
                  child: CircularProgressIndicator(strokeWidth: 2, color: mq.ink3),
                )
              : Icon(icon, size: MqSize.iconMd, color: fg),
        ),
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
            Icon(Icons.error_outline_rounded, size: 48, color: mq.error),
            const SizedBox(height: MqSpacing.md),
            Text(message,
                textAlign: TextAlign.center, style: context.text.bodyMedium),
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
