// Per-conversation controller. One instance lives for the lifetime of a
// `TeacherConversationScreen`; controllers are disposed via GetX when the
// route pops.
//
// Responsibilities:
//   - Load the initial 30 messages + the conversation header.
//   - Load older messages on scroll-to-top (cursor pagination via `before`).
//   - Optimistic send: stage a `ChatMessage(status: sending)` in the list,
//     POST via REST (which also broadcasts `message:new` from the service
//     back to us — we dedupe by `clientMessageId`).
//   - Subscribe to `message:new`, `message:deleted`, `message:pin_updated`,
//     `message:typing`, `conversation:read` and update the local list.
//   - Mark messages read when the screen mounts and on every new inbound.
//   - Send typing pings (throttled — 1 per 3 s).
//
// Permission checks ride on the controller's cached `myRole` so the screen
// can flip buttons without re-fetching.

import 'dart:async';

import 'package:get/get.dart';

import '../models/chat_models.dart';
import '../services/chat_api_service.dart';
import '../services/chat_socket_service.dart';
import '../services/chat_unread_service.dart';

class ConversationController extends GetxController {
  ConversationController({
    required this.conversationId,
    required this.myUserId,
  });

  final String conversationId;
  final String myUserId;

  final Rxn<ChatConversation> conversation = Rxn<ChatConversation>();
  final RxList<ChatMessage> messages = <ChatMessage>[].obs;
  final RxList<ChatMember> members = <ChatMember>[].obs;
  final RxBool loading = false.obs;
  final RxBool loadingMore = false.obs;
  final RxBool sending = false.obs;
  final RxBool hasMore = true.obs;
  final RxnString error = RxnString();
  final RxnString typingUserName = RxnString();

  /// Set to true when the server tells us the current user no longer belongs
  /// to this conversation — either by a `member:removed` socket event whose
  /// payload userId matches ours, or by a 403/FORBIDDEN on fetch (e.g. after
  /// the room is left or the group is archived). Screens watch this and pop
  /// with a "you no longer have access" notice.
  final RxBool iWasRemoved = false.obs;

  /// Computed convenience — am I currently muted by an admin in this group?
  bool get isAdminMuted {
    final me = members.firstWhereOrNull((m) => m.userId == myUserId);
    return me?.isMutedNow == true;
  }

  /// Optional mute-until timestamp for the disabled-composer hint.
  DateTime? get mutedUntil {
    final me = members.firstWhereOrNull((m) => m.userId == myUserId);
    return me?.isMutedByAdminUntil;
  }

  final ChatApiService _api = ChatApiService.instance;
  final ChatSocketService _sock = ChatSocketService.instance;
  final List<void Function()> _unsubs = [];
  Timer? _typingDismiss;
  DateTime _lastTypingEmit = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void onInit() {
    super.onInit();
    _wireSocket();
    fetch();
  }

  Future<void> fetch() async {
    loading.value = true;
    error.value = null;
    try {
      final convData = await _api.getConversation(conversationId);
      final c = convData['conversation'];
      if (c is Map) {
        final conv = ChatConversation.fromJson(Map<String, dynamic>.from(c));
        // /chat/conversations/:id returns the bare conversation row; the
        // caller's role lives in `data.me.role`. Stitch it back in so the
        // UI's owner/admin gates (announce-only send, pin, manage) work.
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
          if (me['notificationsMuted'] == true) {
            conv.notificationsMuted = true;
          }
        }
        conversation.value = conv;
      }
      final m = convData['members'];
      if (m is List) {
        members.assignAll(
          m.whereType<Map>().map(
                (raw) => ChatMember.fromJson(Map<String, dynamic>.from(raw)),
              ),
        );
      }
      final list = await _api.listMessages(conversationId, limit: 30);
      // The endpoint returns newest first; we keep that order in storage and
      // reverse-flip the ListView for visual rendering.
      messages.assignAll(list);
      hasMore.value = list.length >= 30;

      // Mark as read up to the latest known message.
      if (list.isNotEmpty) {
        unawaited(
          _api
              .markRead(conversationId, lastReadMessageId: list.first.id)
              .catchError((_) {}),
        );
        // Optimistic — drop the navbar badge immediately, before the
        // server's `conversation:read` broadcast lands. Covers the
        // direct-from-notification path that doesn't go through the list.
        try {
          ChatUnreadService.instance.markConversationRead(conversationId);
        } catch (_) {/* service not registered */}
      }
    } catch (e) {
      // A 403 here means the server kicked us out of the conversation
      // between the time the list was loaded and now (group archived,
      // member removed, etc.). Surface it as `iWasRemoved` so the screen
      // can close gracefully instead of showing a generic "tap to retry".
      final s = e.toString();
      if (s.contains('403') || s.contains('FORBIDDEN')) {
        iWasRemoved.value = true;
      }
      error.value = _humanise(e);
    } finally {
      loading.value = false;
    }
  }

  /// Fetch the next page of OLDER messages, anchored on the oldest message
  /// we currently hold.
  Future<void> loadOlder() async {
    if (loadingMore.value || !hasMore.value || messages.isEmpty) return;
    loadingMore.value = true;
    try {
      // Oldest message — messages list is newest-first, so the LAST element
      // is the oldest.
      final cursor = messages.last.id;
      final older = await _api.listMessages(
        conversationId,
        before: cursor,
        limit: 30,
      );
      if (older.isEmpty) {
        hasMore.value = false;
      } else {
        messages.addAll(older);
        hasMore.value = older.length >= 30;
      }
    } catch (_) {
      // Stay quiet — top of list will just stop loading; user can retry.
    } finally {
      loadingMore.value = false;
    }
  }

  // ---------------------------------------------------------------------------
  //  Send (optimistic + ack)
  // ---------------------------------------------------------------------------

  /// Stages an optimistic message in the local list, then POSTs. Resolves
  /// when the server returns the persisted row (which replaces the optimistic
  /// stub via `clientMessageId` correlation).
  Future<void> send({
    String? body,
    List<String>? attachmentIds,
  }) async {
    if ((body == null || body.trim().isEmpty) &&
        (attachmentIds == null || attachmentIds.isEmpty)) {
      return;
    }
    final clientId =
        '${DateTime.now().microsecondsSinceEpoch}-${myUserId.substring(0, 8)}';
    final optimistic = ChatMessage(
      id: clientId,
      clientMessageId: clientId,
      conversationId: conversationId,
      senderId: myUserId,
      body: body,
      kind: (attachmentIds != null && attachmentIds.isNotEmpty)
          ? MessageKind.image // placeholder; real kind comes back from server
          : MessageKind.text,
      createdAt: DateTime.now(),
      attachments: const [],
      status: MessageStatus.sending,
    );
    messages.insert(0, optimistic);
    sending.value = true;
    try {
      final saved = await _api.sendMessage(
        conversationId: conversationId,
        body: body,
        attachmentIds: attachmentIds,
      );
      _replaceOptimistic(clientId, saved);
    } catch (_) {
      final idx = messages.indexWhere((m) => m.clientMessageId == clientId);
      if (idx != -1) {
        messages[idx].status = MessageStatus.failed;
        messages.refresh();
      }
    } finally {
      sending.value = false;
    }
  }

  /// Reconcile the locally-staged optimistic message with the row the
  /// server actually persisted.
  ///
  /// Two race orderings are possible because REST and Socket.IO travel on
  /// independent connections:
  ///
  ///   A) REST response arrives first → upgrade optimistic in place
  ///      (id flips from clientId to server id, status → sent).
  ///   B) Socket `message:new` arrives first → it already promoted the
  ///      optimistic to carry the server id (`_onMessageNew` did the swap),
  ///      so the optimistic row is no longer findable by `clientMessageId`.
  ///      In that case this method is a confirming no-op.
  void _replaceOptimistic(String clientId, ChatMessage saved) {
    final idx = messages.indexWhere((m) => m.clientMessageId == clientId);
    if (idx == -1) {
      // Socket beat us — promotion already happened. No mutation needed.
      return;
    }
    final existing = messages[idx];
    if (existing.id == saved.id) {
      // Socket promoted in-place; confirm status only.
      existing.status = MessageStatus.sent;
      messages.refresh();
      return;
    }
    saved.clientMessageId = clientId;
    saved.status = MessageStatus.sent;
    messages[idx] = saved;
    messages.refresh();
  }

  /// Retry a previously-failed send. Re-uses the existing optimistic bubble.
  Future<void> retrySend(ChatMessage failed) async {
    if (failed.status != MessageStatus.failed) return;
    final idx = messages.indexWhere((m) => identical(m, failed));
    if (idx == -1) return;
    failed.status = MessageStatus.sending;
    messages.refresh();
    try {
      final saved = await _api.sendMessage(
        conversationId: conversationId,
        body: failed.body,
        attachmentIds: failed.attachments.map((a) => a.id).toList(),
      );
      saved.clientMessageId = failed.clientMessageId;
      saved.status = MessageStatus.sent;
      messages[idx] = saved;
      messages.refresh();
    } catch (_) {
      failed.status = MessageStatus.failed;
      messages.refresh();
    }
  }

  // ---------------------------------------------------------------------------
  //  Typing
  // ---------------------------------------------------------------------------

  /// Called on each keystroke. Throttled to one emit per 3 s.
  void typing() {
    final now = DateTime.now();
    if (now.difference(_lastTypingEmit).inMilliseconds < 3000) return;
    _lastTypingEmit = now;
    _sock.emit('message:typing', {'conversationId': conversationId});
  }

  // ---------------------------------------------------------------------------
  //  Delete + Pin
  // ---------------------------------------------------------------------------

  Future<void> deleteMessage(ChatMessage m) async {
    try {
      await _api.deleteMessage(m.id);
      // Server emits message:deleted; the handler will update the list. But
      // optimistic update so the bubble flips immediately.
      m.deletedAt = DateTime.now();
      messages.refresh();
    } catch (_) {
      // No-op on failure — server-side check will surface in the snackbar
      // from the screen.
      rethrow;
    }
  }

  Future<void> togglePin(ChatMessage m) async {
    try {
      await _api.togglePin(m.id, !m.isPinned);
      m.isPinned = !m.isPinned;
      messages.refresh();
    } catch (_) {
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  //  Socket events for this conversation
  // ---------------------------------------------------------------------------

  void _wireSocket() {
    _unsubs
      ..add(_sock.on('message:new', _onMessageNew))
      ..add(_sock.on('message:deleted', _onMessageDeleted))
      ..add(_sock.on('message:pin_updated', _onPinUpdated))
      ..add(_sock.on('message:typing', _onTyping))
      ..add(_sock.on('group:updated', _onGroupUpdated))
      ..add(_sock.on('member:added', _onMembersChanged))
      ..add(_sock.on('member:removed', _onMemberRemoved));
  }

  void _onMemberRemoved(dynamic data) {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    if (map['conversationId'] != conversationId) return;
    final removedUserId = map['userId']?.toString();
    if (removedUserId == myUserId) {
      // The current user is the one removed — short-circuit any further fetch
      // (it would 403 anyway) and let the screen close.
      iWasRemoved.value = true;
      return;
    }
    // Someone else was removed; refresh the member list / header.
    fetch();
  }

  void _onMessageNew(dynamic data) {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    if (map['conversationId'] != conversationId) return;
    final msg = ChatMessage.fromJson(map);

    // ── Layer 1: dedupe by server id ──────────────────────────────────────
    // If we've already seen this message (REST path populated it first),
    // bail out — no duplicate bubble.
    if (messages.any((m) => m.id == msg.id)) {
      return;
    }

    // ── Layer 2: socket-beat-REST race ────────────────────────────────────
    // If the sender is me and there's still a pending optimistic message
    // with matching content, this broadcast IS my own send arriving before
    // the REST response. Promote the optimistic in place — same row,
    // same position, real server id + sent status.
    if (msg.senderId == myUserId) {
      final optIdx = messages.indexWhere(
        (m) =>
            m.clientMessageId != null &&
            m.status == MessageStatus.sending &&
            m.senderId == myUserId &&
            (m.body ?? '') == (msg.body ?? ''),
      );
      if (optIdx != -1) {
        final opt = messages[optIdx];
        // Carry the clientMessageId on the promoted row so the REST
        // response's `_replaceOptimistic` can find it as a no-op confirm.
        msg.clientMessageId = opt.clientMessageId;
        msg.status = MessageStatus.sent;
        messages[optIdx] = msg;
        messages.refresh();
        return;
      }
    }

    // ── New inbound message ───────────────────────────────────────────────
    messages.insert(0, msg);
    // Mark read since I'm looking at it.
    unawaited(
      _api
          .markRead(conversationId, lastReadMessageId: msg.id)
          .catchError((_) {}),
    );
  }

  void _onMessageDeleted(dynamic data) {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    if (map['conversationId'] != conversationId) return;
    final messageId = map['messageId']?.toString();
    if (messageId == null) return;
    final idx = messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    messages[idx].deletedAt = DateTime.now();
    messages.refresh();
  }

  void _onPinUpdated(dynamic data) {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    if (map['conversationId'] != conversationId) return;
    final messageId = map['messageId']?.toString();
    final pinned = map['pinned'] == true;
    if (messageId == null) return;
    final idx = messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    messages[idx].isPinned = pinned;
    messages.refresh();
  }

  void _onTyping(dynamic data) {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    if (map['conversationId'] != conversationId) return;
    final uid = map['userId']?.toString();
    if (uid == null || uid == myUserId) return;
    final m = members.firstWhereOrNull((m) => m.userId == uid);
    typingUserName.value = m?.profile?.name ?? 'يكتب';
    _typingDismiss?.cancel();
    _typingDismiss = Timer(const Duration(seconds: 4), () {
      typingUserName.value = null;
    });
  }

  void _onGroupUpdated(dynamic data) {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    if (map['conversationId'] != conversationId) return;
    // Pull header again so the screen reflects renamed / mode-changed group.
    fetch();
  }

  void _onMembersChanged(dynamic data) {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    if (map['conversationId'] != conversationId) return;
    fetch();
  }

  @override
  void onClose() {
    _typingDismiss?.cancel();
    for (final u in _unsubs) {
      u();
    }
    super.onClose();
  }

  String _humanise(Object e) {
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('Failed host lookup')) {
      return 'تحقّق من الإنترنت ثم حاول مجدّداً.';
    }
    if (s.contains('403') || s.contains('FORBIDDEN')) {
      return 'لا تملك صلاحية الوصول لهذه المحادثة.';
    }
    return 'تعذّر تحميل الرسائل.';
  }
}
