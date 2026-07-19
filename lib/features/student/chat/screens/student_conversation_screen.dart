// Student-side single-conversation screen — Phase 7 (MulhimIQ design-system pass).
//
// Reuses ConversationController for all state + socket wiring; the screen just
// renders bubbles and a composer. This pass restyles the UI with the MulhimIQ
// design system — every controller / socket / send / read / typing path is
// untouched.
//
// Student-vs-teacher behavioural deltas (preserved):
//   • No group-settings button.
//   • Long-press menu shows only "حذف الرسالة" for own messages (5-min window).
//   • Composer disabled when announce-only+member / admin-muted / removed.
//   • iWasRemoved watcher pops the screen on server `member:removed`.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/utils/time_format.dart';
import '../../../teacher/chat/controllers/conversation_controller.dart';
import '../../../teacher/chat/models/chat_models.dart';
import '../../../teacher/chat/services/chat_api_service.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';
import 'student_conversations_screen.dart'
    show ChatAvatar, chatRoleBadge, ChatConnectionBanner;

class StudentConversationScreen extends StatefulWidget {
  const StudentConversationScreen({
    super.key,
    required this.conversationId,
    required this.initialTitle,
    required this.myUserId,
  });

  final String conversationId;
  final String initialTitle;
  final String myUserId;

  @override
  State<StudentConversationScreen> createState() =>
      _StudentConversationScreenState();
}

class _StudentConversationScreenState extends State<StudentConversationScreen> {
  late final ConversationController _ctrl;
  late final TextEditingController _composer;
  late final ScrollController _scroll;
  late final FocusNode _messageFocus;
  final _picker = ImagePicker();
  bool _uploading = false;
  Worker? _removalWatcher;

  @override
  void initState() {
    super.initState();
    _composer = TextEditingController();
    _scroll = ScrollController();
    _messageFocus = FocusNode(debugLabel: 'student-chat-composer');
    _ctrl = Get.put(
      ConversationController(
        conversationId: widget.conversationId,
        myUserId: widget.myUserId,
      ),
      tag: 'student-conv-${widget.conversationId}',
    );
    _scroll.addListener(_onScroll);
    // Pop the screen the moment the server tells us we no longer belong here.
    _removalWatcher = ever<bool>(_ctrl.iWasRemoved, (removed) {
      if (!removed || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لم تعد عضواً في هذه المحادثة.'),
          duration: Duration(seconds: 2),
        ),
      );
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        if (mounted) Get.back();
      });
    });
  }

  @override
  void dispose() {
    _removalWatcher?.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _composer.dispose();
    _messageFocus.dispose();
    Get.delete<ConversationController>(
      tag: 'student-conv-${widget.conversationId}',
    );
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _ctrl.loadOlder();
    }
  }

  // ── Permission predicates ────────────────────────────────────────────────

  /// Why is the composer disabled? Returns `null` when sending is allowed.
  String? _composerDisabledReason() {
    final c = _ctrl.conversation.value;
    if (c == null) return null;
    if (_ctrl.iWasRemoved.value) {
      return 'تم إزالتك من هذه المحادثة.';
    }
    if (c.mode == ConversationMode.announceOnly && !c.canManage) {
      return 'هذه المجموعة للإعلانات فقط — لا يمكن للأعضاء الإرسال.';
    }
    if (_ctrl.isAdminMuted) {
      final until = _ctrl.mutedUntil;
      if (until != null) {
        return 'أنت مكتوم في هذه المجموعة حتى ${formatDateTime12(until)}.';
      }
      return 'أنت مكتوم في هذه المجموعة من قِبل المشرف.';
    }
    return null;
  }

  Future<void> _submit() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    _composer.clear();
    await _ctrl.send(body: text);
  }

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
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

  void _showMessageMenu(ChatMessage m, bool isMine) {
    // Students can ONLY delete their own messages within the 5-minute window.
    final canDeleteOwn =
        isMine && DateTime.now().difference(m.createdAt).inMinutes < 5;
    if (m.isDeleted || !canDeleteOwn) return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.delete_outline, color: ctx.mq.error),
              title: Text('حذف الرسالة', style: TextStyle(color: ctx.mq.error)),
              onTap: () async {
                Navigator.of(ctx).pop();
                try {
                  await _ctrl.deleteMessage(m);
                } catch (e) {
                  _showError(e);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('فشلت العملية: ${_errorMsg(e)}')));
  }

  Future<void> _retry(ChatMessage failed) async {
    await _ctrl.retrySend(failed);
  }

  // ── Build ────────────────────────────────────────────────────────────────

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
            resizeToAvoidBottomInset: true,
            appBar: AppBar(
              titleSpacing: 0,
              title: Obx(
                () => _ChatHeader(
                  conversation: _ctrl.conversation.value,
                  fallbackTitle: widget.initialTitle,
                ),
              ),
            ),
            body: Obx(() {
              if (_ctrl.loading.value && _ctrl.messages.isEmpty) {
                return _Skeleton();
              }
              if (_ctrl.error.value != null && _ctrl.messages.isEmpty) {
                return _ErrorView(
                  message: _ctrl.error.value!,
                  onRetry: _ctrl.fetch,
                );
              }
              return Column(
                children: [
                  const ChatConnectionBanner(),
                  _AnnounceOnlyBanner(controller: _ctrl),
                  Expanded(
                    child: _ctrl.messages.isEmpty
                        ? const _EmptyMessages()
                        : ListView.builder(
                            controller: _scroll,
                            reverse: true,
                            padding: const EdgeInsets.symmetric(
                              horizontal: MqSpacing.md,
                              vertical: MqSpacing.sm,
                            ),
                            itemCount:
                                _ctrl.messages.length +
                                (_ctrl.loadingMore.value ? 1 : 0),
                            itemBuilder: (ctx, idx) {
                              if (_ctrl.loadingMore.value &&
                                  idx == _ctrl.messages.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: MqSpacing.md,
                                  ),
                                  child: Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
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
                                onRetry:
                                    m.status == MessageStatus.failed && isMine
                                    ? () => _retry(m)
                                    : null,
                              );
                            },
                          ),
                  ),
                  Obx(() {
                    final typing = _ctrl.typingUserName.value;
                    if (typing == null) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MqSpacing.lg,
                        vertical: MqSpacing.xs,
                      ),
                      alignment: Alignment.centerRight,
                      child: Text(
                        '$typing يكتب…',
                        style: context.text.labelSmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: context.mq.ink3,
                        ),
                      ),
                    );
                  }),
                  _Composer(
                    controller: _composer,
                    focusNode: _messageFocus,
                    disabledReason: _composerDisabledReason(),
                    uploading: _uploading,
                    onSubmit: _submit,
                    onAttach: _pickImage,
                    onTyping: _ctrl.typing,
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Header
// ---------------------------------------------------------------------------

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.conversation, required this.fallbackTitle});
  final ChatConversation? conversation;
  final String fallbackTitle;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final name = c?.displayName() ?? fallbackTitle;
    final role = c == null ? null : chatRoleBadge(c);
    return Row(
      children: [
        ChatAvatar(
          name: name,
          isGroup: c?.isGroup ?? false,
          imagePath: c?.peer?.profileImagePath,
          size: 38,
        ),
        MqSpacing.gapSm,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleSmall,
              ),
              if (role != null && role.label.isNotEmpty)
                Text(role.label, style: context.text.labelSmall),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
//  Banners / states
// ---------------------------------------------------------------------------

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
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: MqSpacing.lg,
          vertical: MqSpacing.sm,
        ),
        color: mq.orangeSoft,
        child: Row(
          children: [
            Icon(Icons.campaign_outlined, size: 15, color: mq.orangeDeep),
            MqSpacing.gapSm,
            Expanded(
              child: Text(
                'هذه المجموعة للإعلانات فقط — يمكنك القراءة دون الإرسال.',
                style: context.text.labelMedium?.copyWith(color: mq.orangeDeep),
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
            padding: const EdgeInsets.all(MqSpacing.lg),
            decoration: BoxDecoration(
              color: mq.accentSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 40,
              color: mq.accent,
            ),
          ),
          MqSpacing.gapMd,
          Text('لا توجد رسائل بعد', style: context.text.titleSmall),
          MqSpacing.gapXs,
          Text('ابدأ المحادثة بأول رسالة.', style: context.text.bodySmall),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    Widget bubble(bool mine, double w) => Align(
      alignment: mine ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        width: w,
        height: 38,
        margin: const EdgeInsets.symmetric(
          vertical: 4,
          horizontal: MqSpacing.md,
        ),
        decoration: BoxDecoration(color: mq.fill2, borderRadius: MqRadius.brLg),
      ),
    );
    return ListView(
      reverse: true,
      padding: const EdgeInsets.all(MqSpacing.md),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        bubble(true, 160),
        bubble(false, 220),
        bubble(true, 120),
        bubble(false, 200),
        bubble(true, 180),
        bubble(false, 140),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
//  Message bubble
// ---------------------------------------------------------------------------

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.isMine,
    required this.onLongPress,
    this.onRetry,
  });
  final ChatMessage message;
  final bool isMine;
  final VoidCallback onLongPress;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final deleted = message.isDeleted;
    final bg = deleted ? mq.fill : (isMine ? mq.accent : mq.card);
    final fg = isMine && !deleted ? mq.onAccent : mq.ink;
    final time = formatTime12(message.createdAt);

    return Align(
      alignment: isMine ? Alignment.centerLeft : Alignment.centerRight,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(
            vertical: 3,
            horizontal: MqSpacing.xs,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: MqSpacing.md,
            vertical: MqSpacing.sm,
          ),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            color: bg,
            border: isMine ? null : Border.all(color: mq.line),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(MqRadius.lg),
              topRight: const Radius.circular(MqRadius.lg),
              bottomLeft: Radius.circular(isMine ? 4 : MqRadius.lg),
              bottomRight: Radius.circular(isMine ? MqRadius.lg : 4),
            ),
            boxShadow: isMine ? null : mq.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isMine && message.sender != null && !deleted) ...[
                Text(
                  message.sender!.name,
                  style: context.text.labelSmall?.copyWith(
                    color: mq.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              if (message.isPinned && !deleted)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.push_pin,
                        size: 12,
                        color: isMine ? mq.onAccent : mq.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'مثبّتة',
                        style: context.text.labelSmall?.copyWith(
                          color: isMine ? mq.onAccent : mq.orange,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              if (deleted)
                Text(
                  'تم حذف هذه الرسالة',
                  style: context.text.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: mq.ink3,
                  ),
                )
              else ...[
                for (final a in message.attachments) _AttachmentView(att: a),
                if ((message.body ?? '').isNotEmpty)
                  Text(
                    message.body!,
                    style: context.text.bodyMedium?.copyWith(
                      color: fg,
                      height: 1.35,
                    ),
                  ),
              ],
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: context.text.labelSmall?.copyWith(
                      color: fg.withValues(alpha: 0.6),
                      fontSize: 10,
                    ),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 4),
                    _StatusGlyph(status: message.status, color: fg),
                    if (message.status == MessageStatus.failed &&
                        onRetry != null) ...[
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: onRetry,
                        borderRadius: MqRadius.brSm,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh, size: 11, color: mq.onAccent),
                              const SizedBox(width: 2),
                              Text(
                                'إعادة',
                                style: context.text.labelSmall?.copyWith(
                                  color: mq.onAccent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
        return Icon(
          Icons.schedule,
          size: 11,
          color: color.withValues(alpha: 0.6),
        );
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
        padding: const EdgeInsets.only(bottom: 6),
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.all(MqSpacing.sm),
        decoration: BoxDecoration(
          color: mq.fill,
          borderRadius: MqRadius.brMd,
          border: Border.all(color: mq.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconData, size: 22, color: mq.accent),
            MqSpacing.gapSm,
            Flexible(
              child: Text(
                att.originalName ?? att.url.split('/').last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Composer
// ---------------------------------------------------------------------------

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.disabledReason,
    required this.uploading,
    required this.onSubmit,
    required this.onAttach,
    required this.onTyping,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? disabledReason;
  final bool uploading;
  final Future<void> Function() onSubmit;
  final Future<void> Function() onAttach;
  final VoidCallback onTyping;

  bool get _canSend => disabledReason == null;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          MqSpacing.sm,
          MqSpacing.sm,
          MqSpacing.sm,
          MqSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: mq.card,
          border: Border(top: BorderSide(color: mq.line)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_canSend)
              Padding(
                padding: const EdgeInsets.only(bottom: MqSpacing.xs),
                child: MqSurface(
                  tone: MqSurfaceTone.neutral,
                  padding: const EdgeInsets.symmetric(
                    horizontal: MqSpacing.sm,
                    vertical: MqSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 13,
                        color: mq.ink3,
                      ),
                      MqSpacing.gapXs,
                      Expanded(
                        child: Text(
                          disabledReason!,
                          style: context.text.labelSmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: _canSend && !uploading ? () => onAttach() : null,
                  icon: uploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.attach_file_outlined, color: mq.ink2),
                ),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      enabled: _canSend,
                      autofocus: false,
                      onChanged: (_) => onTyping(),
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: mq.fill,
                        hintText: _canSend ? 'اكتب رسالتك…' : 'الإرسال متوقّف',
                        border: const OutlineInputBorder(
                          borderRadius: MqRadius.brXl,
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: MqSpacing.md,
                          vertical: MqSpacing.sm,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: MqSpacing.xs),
                Material(
                  color: _canSend ? mq.accent : mq.fill2,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _canSend ? () => onSubmit() : null,
                    child: Padding(
                      padding: const EdgeInsets.all(MqSpacing.sm),
                      child: Icon(
                        Icons.send_rounded,
                        color: _canSend ? mq.onAccent : mq.ink3,
                        size: MqSize.iconMd,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
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
            Icon(Icons.error_outline, size: 44, color: mq.error),
            MqSpacing.gapMd,
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium,
            ),
            MqSpacing.gapMd,
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
