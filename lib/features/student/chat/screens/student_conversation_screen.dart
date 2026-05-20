// Student-side single-conversation screen — Phase 7.
//
// Reuses ConversationController for all state + socket wiring; the screen
// just renders bubbles and a composer.
//
// Student-vs-teacher behavioural deltas (everything else is identical):
//
//   • No group-settings button (students cannot manage members / rename /
//     archive — already enforced server-side, but the entry point is hidden
//     too).
//   • Long-press menu shows only "حذف الرسالة" for own messages within the
//     5-minute window. No pin, no delete-others'.
//   • Composer is disabled when ANY of:
//        - conversation is announce_only AND I am role=member
//        - I am admin-muted (member.isMutedByAdminUntil > now)
//        - I was removed from the conversation (mid-session)
//     The hint text under the field explains which case applies.
//   • A `iWasRemoved` watcher pops the screen with a snackbar the moment the
//     server emits `member:removed` for our userId.
//
// Realtime: every socket subscription (message:new, typing, read, deleted,
// pin_updated, group:updated, member:added/removed) already lives in the
// shared controller — no copy here.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_config.dart';
import '../../../teacher/chat/controllers/conversation_controller.dart';
import '../../../teacher/chat/models/chat_models.dart';
import '../../../teacher/chat/services/chat_api_service.dart';

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
      // Defer the pop slightly so the snackbar gets a chance to render.
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
        final fmt = DateFormat('dd/MM HH:mm');
        return 'أنت مكتوم في هذه المجموعة حتى ${fmt.format(until.toLocal())}.';
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

  void _showMessageMenu(ChatMessage m, bool isMine) {
    // Students can ONLY delete their own messages within the 5-minute window.
    // No pin, no delete-others' — those are owner/admin actions.
    final canDeleteOwn =
        isMine && DateTime.now().difference(m.createdAt).inMinutes < 5;
    if (m.isDeleted || !canDeleteOwn) return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(ctx).colorScheme.error),
              title: Text(
                'حذف الرسالة',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('فشلت العملية: ${_errorMsg(e)}')),
    );
  }

  Future<void> _retry(ChatMessage failed) async {
    await _ctrl.retrySend(failed);
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Obx(
          () => Text(
            _ctrl.conversation.value?.displayName() ?? widget.initialTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      body: Obx(() {
        if (_ctrl.loading.value && _ctrl.messages.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_ctrl.error.value != null && _ctrl.messages.isEmpty) {
          return _ErrorView(
            message: _ctrl.error.value!,
            onRetry: _ctrl.fetch,
          );
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
                          horizontal: 8, vertical: 8),
                      itemCount: _ctrl.messages.length +
                          (_ctrl.loadingMore.value ? 1 : 0),
                      itemBuilder: (ctx, idx) {
                        if (_ctrl.loadingMore.value &&
                            idx == _ctrl.messages.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                alignment: Alignment.centerRight,
                child: Text(
                  '$typing يكتب…',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: cs.onSurfaceVariant,
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
    );
  }
}

// ---------------------------------------------------------------------------
//  Sub-widgets — mirror the teacher screen visually so students see the same
//  bubbles / banners / composer aesthetic.
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
      final cs = Theme.of(context).colorScheme;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        color: cs.tertiaryContainer.withValues(alpha: 0.4),
        child: Row(
          children: [
            Icon(Icons.campaign_outlined, size: 14, color: cs.onSurface),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'هذه المجموعة للإعلانات فقط — يمكنك القراءة دون الإرسال.',
                style: TextStyle(fontSize: 11),
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
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Text('لا توجد رسائل بعد',
              style: TextStyle(color: cs.onSurfaceVariant)),
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
    this.onRetry,
  });
  final ChatMessage message;
  final bool isMine;
  final VoidCallback onLongPress;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = message.isDeleted
        ? cs.surfaceContainerHighest
        : (isMine ? cs.primaryContainer : cs.surfaceContainerHighest);
    final fg = isMine ? cs.onPrimaryContainer : cs.onSurface;
    final time = DateFormat('HH:mm').format(message.createdAt.toLocal());

    return Align(
      alignment: isMine ? Alignment.centerLeft : Alignment.centerRight,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft:
                  isMine ? const Radius.circular(4) : const Radius.circular(14),
              bottomRight:
                  isMine ? const Radius.circular(14) : const Radius.circular(4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isMine && message.sender != null) ...[
                Text(
                  message.sender!.name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              if (message.isPinned)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.push_pin, size: 12, color: cs.tertiary),
                      const SizedBox(width: 4),
                      Text('مثبّتة',
                          style: TextStyle(
                              fontSize: 10,
                              color: cs.tertiary,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              if (message.isDeleted)
                Text('تم حذف هذه الرسالة',
                    style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: cs.onSurfaceVariant))
              else ...[
                for (final a in message.attachments) _AttachmentView(att: a),
                if ((message.body ?? '').isNotEmpty)
                  Text(
                    message.body!,
                    style: TextStyle(color: fg, fontSize: 14, height: 1.35),
                  ),
              ],
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(time,
                      style: TextStyle(
                          fontSize: 10,
                          color: fg.withValues(alpha: 0.6))),
                  if (isMine) ...[
                    const SizedBox(width: 4),
                    _StatusGlyph(status: message.status, color: fg),
                    if (message.status == MessageStatus.failed &&
                        onRetry != null) ...[
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: onRetry,
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh,
                                  size: 11, color: cs.error),
                              const SizedBox(width: 2),
                              Text('إعادة',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: cs.error,
                                      fontWeight: FontWeight.bold)),
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
        return Icon(Icons.schedule,
            size: 11, color: color.withValues(alpha: 0.6));
      case MessageStatus.failed:
        return Icon(Icons.error_outline,
            size: 11, color: Theme.of(context).colorScheme.error);
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
    final cs = Theme.of(context).colorScheme;
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
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            thumb ?? url,
            width: 220,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 220,
              height: 140,
              color: cs.surfaceContainerHighest,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined),
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
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconData, size: 22, color: cs.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                att.originalName ?? att.url.split('/').last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
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
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(
            top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_canSend)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, right: 4, left: 4),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 12, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        disabledReason!,
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
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
                      : const Icon(Icons.attach_file_outlined),
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
                        hintText: _canSend
                            ? 'اكتب رسالتك…'
                            : 'الإرسال متوقّف',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton.filled(
                  onPressed: _canSend ? () => onSubmit() : null,
                  icon: const Icon(Icons.send),
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
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: cs.error),
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
